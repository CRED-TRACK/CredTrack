"""
add_colors.py — Enrich BIN-list CSVs with bank brand colours.

Three-strategy pipeline for bin-list-data-US-credit-issuers.csv:
  S1: URL-domain match against banks-db brand colours (fast, accurate)
  S2: Exact + fuzzy issuer-name match from BIN-derived colour map
  S3: Live website scraping for <meta name="theme-color"> (threaded)
"""

import csv
import difflib
import html.parser
import json
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
GITHUB_TREE_URL = (
    "https://api.github.com/repos/ramoona/banks-db/git/trees/main?recursive=1"
)
RAW_BASE = "https://raw.githubusercontent.com/ramoona/banks-db/main/"
BASE_DIR = "/Users/siddharthnashikkar/Downloads/bin-list-data-master/"

BIN_FILES = [
    "bin-list-data.csv",
    "bin-list-data-US.csv",
    "bin-list-data-US-credit.csv",
]
ISSUERS_FILE = "bin-list-data-US-credit-issuers.csv"

SCRAPE_WORKERS = 20
SCRAPE_TIMEOUT = 6       # seconds per request
FUZZY_CUTOFF = 0.75      # difflib similarity threshold

HEX_RE = re.compile(r"^#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?$")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def fetch_json(url, retries=3):
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": "bin-color-enricher/1.0"}
            )
            with urllib.request.urlopen(req, timeout=15) as resp:
                return json.loads(resp.read().decode())
        except Exception as exc:
            if attempt < retries - 1:
                time.sleep(1)
            else:
                raise exc


def extract_domain(url: str) -> str:
    """Return lowercase bare domain, stripping 'www.' prefix."""
    try:
        host = urllib.parse.urlparse(url.strip()).hostname or ""
        host = host.lower()
        if host.startswith("www."):
            host = host[4:]
        return host
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# HTML parser to find theme-color meta tags
# ---------------------------------------------------------------------------
class ThemeColorParser(html.parser.HTMLParser):
    NAMES = {"theme-color", "msapplication-tilecolor"}

    def __init__(self):
        super().__init__()
        self.color = ""

    def handle_starttag(self, tag, attrs):
        if self.color or tag.lower() != "meta":
            return
        attr_dict = {k.lower(): (v or "").strip() for k, v in attrs}
        if attr_dict.get("name", "").lower() in self.NAMES:
            val = attr_dict.get("content", "")
            if HEX_RE.match(val):
                self.color = val


def fetch_theme_color(url: str) -> str:
    """Fetch a URL and return its theme-color hex value, or '' on failure."""
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (compatible; BinColorBot/1.0)"
                )
            },
        )
        with urllib.request.urlopen(req, timeout=SCRAPE_TIMEOUT, context=ctx) as resp:
            # Read only the first 32 KB — enough for <head>
            chunk = resp.read(32768).decode("utf-8", errors="replace")
        parser = ThemeColorParser()
        parser.feed(chunk)
        return parser.color
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Step 1: Fetch banks-db data → prefix→color + domain→color
# ---------------------------------------------------------------------------
def fetch_banks_db_maps():
    print("Fetching repository tree...")
    tree = fetch_json(GITHUB_TREE_URL)

    bank_paths = [
        item["path"]
        for item in tree.get("tree", [])
        if item["path"].startswith("banks/") and item["path"].endswith(".json")
    ]
    print(f"Found {len(bank_paths)} bank files")

    prefix_color: dict[str, str] = {}
    domain_color: dict[str, str] = {}

    for i, path in enumerate(bank_paths, 1):
        try:
            data = fetch_json(RAW_BASE + path)
            color = data.get("color", "")
            if color:
                for prefix in data.get("prefixes", []):
                    prefix_color[str(prefix)] = color
                bank_url = data.get("url", "")
                if bank_url:
                    d = extract_domain(bank_url)
                    if d:
                        domain_color[d] = color
        except Exception as exc:
            print(f"  Warning: could not fetch {path}: {exc}", file=sys.stderr)
        if i % 20 == 0:
            print(f"  Processed {i}/{len(bank_paths)} bank files...")

    print(f"Built prefix map  : {len(prefix_color):,} BIN prefixes")
    print(f"Built domain map  : {len(domain_color):,} bank domains")
    return prefix_color, domain_color


# ---------------------------------------------------------------------------
# Enrich the three BIN CSV files (BIN prefix lookup — unchanged logic)
# ---------------------------------------------------------------------------
def enrich_bin_file(filename, prefix_color):
    path = BASE_DIR + filename
    print(f"Enriching {filename}...")

    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        if "Color" not in fieldnames:
            fieldnames.append("Color")
        rows = list(reader)

    matched = 0
    for row in rows:
        color = prefix_color.get(str(row.get("BIN", "")), "")
        row["Color"] = color
        if color:
            matched += 1

    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    pct = matched * 100 // len(rows) if rows else 0
    print(f"  {matched:,}/{len(rows):,} rows matched ({pct}%)")
    return rows


# ---------------------------------------------------------------------------
# Build issuer→color from enriched BIN rows
# ---------------------------------------------------------------------------
def build_issuer_color_map(enriched_rows):
    color_counts: dict[str, Counter] = {}
    for row in enriched_rows:
        issuer = row.get("Issuer", "")
        color = row.get("Color", "")
        if issuer and color:
            color_counts.setdefault(issuer, Counter())[color] += 1
    return {issuer: ctr.most_common(1)[0][0] for issuer, ctr in color_counts.items()}


# ---------------------------------------------------------------------------
# Enrich the issuers file — three-strategy pipeline
# ---------------------------------------------------------------------------
def enrich_issuers_file(filename, issuer_color_map, domain_color):
    path = BASE_DIR + filename
    print(f"\nEnriching {filename}...")

    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        if "Color" not in fieldnames:
            fieldnames.append("Color")
        rows = list(reader)

    issuer_keys = list(issuer_color_map.keys())

    s1 = s2_exact = s2_fuzzy = 0

    for row in rows:
        color = ""

        # ---- Strategy 1: URL domain → banks-db ----
        issuer_url = row.get("IssuerUrl", "")
        if issuer_url:
            d = extract_domain(issuer_url)
            color = domain_color.get(d, "")
            if color:
                s1 += 1

        # ---- Strategy 2a: exact issuer-name match ----
        if not color:
            color = issuer_color_map.get(row.get("Issuer", ""), "")
            if color:
                s2_exact += 1

        # ---- Strategy 2b: fuzzy issuer-name match ----
        if not color:
            matches = difflib.get_close_matches(
                row.get("Issuer", ""), issuer_keys, n=1, cutoff=FUZZY_CUTOFF
            )
            if matches:
                color = issuer_color_map[matches[0]]
                if color:
                    s2_fuzzy += 1

        row["Color"] = color

    print(f"  S1 (domain match)   : {s1:,}")
    print(f"  S2 (exact name)     : {s2_exact:,}")
    print(f"  S2 (fuzzy name)     : {s2_fuzzy:,}")

    # ---- Strategy 3: live website theme-color scraping ----
    unmatched = [r for r in rows if not r.get("Color") and r.get("IssuerUrl")]
    print(f"  S3 (web scrape)     : {len(unmatched):,} URLs to try...")

    s3 = 0
    if unmatched:
        with ThreadPoolExecutor(max_workers=SCRAPE_WORKERS) as executor:
            future_to_row = {
                executor.submit(fetch_theme_color, r["IssuerUrl"]): r
                for r in unmatched
            }
            done = 0
            for future in as_completed(future_to_row):
                row = future_to_row[future]
                try:
                    color = future.result()
                    if color:
                        row["Color"] = color
                        s3 += 1
                except Exception:
                    pass
                done += 1
                if done % 200 == 0:
                    print(f"    scraped {done}/{len(unmatched)} ...")

    total_matched = sum(1 for r in rows if r.get("Color"))
    pct = total_matched * 100 // len(rows) if rows else 0
    print(f"  S3 (web scrape)     : {s3:,} hits")
    print(f"  TOTAL matched       : {total_matched:,}/{len(rows):,} ({pct}%)")

    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    prefix_color, domain_color = fetch_banks_db_maps()

    # Enrich BIN files; keep rows from the first (global) file for issuer mapping
    main_rows = None
    for fname in BIN_FILES:
        rows = enrich_bin_file(fname, prefix_color)
        if main_rows is None:
            main_rows = rows

    issuer_color_map = build_issuer_color_map(main_rows or [])
    print(f"\nIssuer colour map   : {len(issuer_color_map):,} unique issuers")

    enrich_issuers_file(ISSUERS_FILE, issuer_color_map, domain_color)

    print("\n✓ Done! All files enriched.")
