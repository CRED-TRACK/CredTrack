# CredTrack

A personal finance app for tracking credit card statements and utility bills, with AI-powered PDF extraction via Gmail. Push notifications delivered via Telegram bot — no APNs / Apple Developer fees required.

---

## Repository Structure

```
CredTrack/
├── CredTrack/          # iOS app (SwiftUI)
├── backend/            # REST API (Spring Boot)
├── DATA/               # BIN lookup CSVs and seed SQL
├── CredTrack_Report.pdf
└── CREDTRACK AI.pptx
```

---

## CredTrack/ — iOS App

Built with SwiftUI, targeting iOS. Authenticates via Firebase and talks to the Spring Boot backend.

```
CredTrack/CredTrack/
├── App/
│   ├── CredTrackApp.swift          # App entry point
│   └── AppStateManager.swift       # Global app state
├── Core/
│   ├── Auth/AuthManager.swift      # Firebase auth
│   ├── Gmail/GmailConnectionManager.swift  # Gmail OAuth flow
│   └── Network/
│       ├── APIClient.swift         # HTTP layer
│       └── APIConfig.swift         # Base URL / endpoints
├── Features/
│   ├── Auth/                       # Login + splash screens
│   ├── Cards/                      # Card list, detail, add card, statements, transactions
│   ├── Utility/                    # Utility accounts, bill list, bill detail
│   ├── Analysis/                   # Card spending + utility bill analytics charts
│   ├── Home/                       # Home dashboard
│   ├── Profile/                    # User profile
│   └── Root/MainTabView.swift      # Tab bar
├── Components/
│   ├── Buttons/                    # SynthButton, CTBackButton, SynthChipButton, etc.
│   ├── Cards/                      # CreditCardView, NeuCard, CardModel
│   └── NeoPop/                     # NeoPop-style UI components
├── Shared/
│   ├── ExtractionPreviewSheet.swift  # Preview before saving extracted data
│   ├── PdfViewer.swift
│   └── WaveBackgroundView.swift    # Metal-backed animated background
├── DesignSystem/DesignSystem.swift  # Colors, fonts, spacing tokens
└── Utils/NeoPopIcons.swift
```

**To run the iOS app:** open `CredTrack/CredTrack.xcodeproj` in Xcode, set your team/bundle ID, and run on a simulator or device. You will need a valid `GoogleService-Info.plist` from your Firebase project placed in `CredTrack/CredTrack/`.

---

## backend/ — Spring Boot API

Java 17 · Spring Boot 3.5 · PostgreSQL · Firebase Admin · PDFBox · Spring AI (Ollama)

```
backend/src/main/java/com/credtrack/backend/
├── controller/
│   ├── AuthController              # POST /auth/register, /auth/login
│   ├── UserCardController          # CRUD for user credit cards
│   ├── StatementController         # Upload & manage card statements
│   ├── TransactionController       # Transactions per statement
│   ├── UtilityBillController       # Utility bill CRUD
│   ├── UserUtilityAccountController# Utility account management
│   ├── AnalyticsController         # Spending analytics endpoints
│   ├── CardProductController       # Card product catalogue
│   ├── BinController               # BIN lookup
│   ├── GmailStatusController       # Gmail OAuth status
│   ├── TelegramController          # Telegram link, prefs, webhook receiver
│   ├── InternalController          # Internal service endpoints (also fires notifications)
│   └── InternalAnalyticsController
├── service/
│   ├── PdfExtractionService        # Extracts transactions from PDF statements
│   ├── AiAgentClient               # Calls local Ollama AI agent
│   ├── GmailOAuthService           # Gmail OAuth token management
│   ├── FirebaseService             # Firebase token verification
│   ├── FirebaseStorageService      # PDF upload/download via Firebase Storage
│   ├── UserCardService             # Card business logic
│   ├── BinService                  # BIN number lookups
│   ├── TelegramService             # Telegram Bot API send + auto-registers webhook on boot
│   └── ...                         # Payment, utility, statement internal services
├── entity/                         # JPA entities: User, UserCard, CardStatement,
│                                   # Transaction, CardPayment, CardProduct, Issuer,
│                                   # BinRecord, GmailCredential, UserUtilityAccount,
│                                   # UtilityBill, UtilityPayment, TelegramLinkToken
├── repository/                     # Spring Data JPA repositories
├── dto/                            # Request/response DTOs
├── config/
│   ├── SecurityConfig              # Spring Security + Firebase token filter
│   ├── FirebaseConfig              # Firebase Admin SDK init
│   ├── WebMvcConfig                # CORS configuration
│   └── ServiceKeyInterceptor       # Internal service key auth
└── scheduler/
    └── PdfExtractionScheduler      # Scheduled Gmail PDF polling + extraction
```

### Prerequisites

- Java 17
- Maven (or use the included `./mvnw` wrapper)
- PostgreSQL 14+

### Environment Setup

```bash
cd backend
cp .env.example .env
```

Edit `.env` and fill in the required values:

| Variable | Description |
|---|---|
| `DB_URL` | JDBC URL, e.g. `jdbc:postgresql://localhost:5433/credtrack` |
| `DB_USERNAME` | Postgres username |
| `DB_PASSWORD` | Postgres password |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage bucket name |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret |
| `ENCRYPTION_KEY` | 32-byte base64 key — generate with `openssl rand -base64 32` |
| `INTERNAL_SERVICE_KEY` | Shared key between backend and AI agent |
| `AI_AGENT_BASE_URL` | Base URL of the AI agent service (default `http://localhost:8081`) |
| `TELEGRAM_BOT_TOKEN` | Token from @BotFather (leave blank to disable notifications) |
| `TELEGRAM_BOT_USERNAME` | Bot username without leading `@`, e.g. `CredTrack_bot` |
| `TELEGRAM_WEBHOOK_SECRET` | Random secret echoed in `X-Telegram-Bot-Api-Secret-Token` header — `openssl rand -hex 32` |
| `TELEGRAM_WEBHOOK_PUBLIC_BASE_URL` | Public HTTPS URL of this backend (used at boot to register `setWebhook`) |

### Create the database

```sql
CREATE DATABASE credtrack;
```

Spring Boot will auto-create the schema on first run (`spring.jpa.hibernate.ddl-auto=update`).

### Run

```bash
cd backend
./mvnw spring-boot:run
```

The API starts on `http://localhost:8080`.

To build a runnable JAR:

```bash
./mvnw clean package
java -jar target/backend-0.0.1-SNAPSHOT.jar
```

---

## Notifications (Telegram)

CredTrack delivers user-facing alerts via a Telegram bot instead of APNs / Firebase Cloud Messaging — no $99/yr Apple Developer Program fee and no business-account hoops. Per-event preferences are user-controlled from the iOS Profile screen (Notifications row).

### Events

| Event | Default | Source |
|---|---|---|
| New statement | **ON** | `POST /internal/statements` |
| New transaction | OFF | `POST /internal/transactions` |
| Payment confirmation | OFF | `POST /internal/payments` |
| Utility bill received | OFF | `POST /internal/utility-bills` |

Notification sends are best-effort and never throw — extraction continues even if the bot is misconfigured or unreachable.

### One-time setup

1. Message `@BotFather` on Telegram, run `/newbot`, save the token and chosen username.
2. Generate a webhook secret: `openssl rand -hex 32`
3. Fill the four `TELEGRAM_*` env vars in `.env` (local) or `terraform.tfvars` (deploy). Leaving `TELEGRAM_BOT_TOKEN` blank disables the feature entirely.
4. On the next backend boot, `TelegramService.registerWebhookOnStartup` calls Telegram's `setWebhook` automatically — no manual curl required. Verify with:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
   ```

### How linking works

```
iOS app  ── POST /api/telegram/link-token ─────────────►  backend mints short-lived token
   │                                                                  │
   │ ◄────────────────  { token, deepLink } ──────────────────────────┘
   │
   ├── opens tg://resolve?domain=<bot>&start=<token>
   │
   └── user taps Start in Telegram
                │
                ▼
   Telegram POST /public/telegram/webhook ──►  backend maps chat_id ↔ userId, deletes token, replies "Linked."
```

Subsequent `POST /internal/*` writes call `TelegramService.notifyIfEnabled(userId, eventType, msg)` — sends only if the user is linked AND has that event toggled on.

### Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/telegram/link-token` | Firebase Bearer | Mint 10-min link token + return deep link |
| `GET`  | `/api/telegram/status` | Firebase Bearer | Returns `{ linked, bot_username, prefs }` |
| `PATCH`| `/api/telegram/preferences` | Firebase Bearer | Partial update of the 4 `notify_*` booleans |
| `DELETE` | `/api/telegram/link` | Firebase Bearer | Unlink — clears `telegram_chat_id` |
| `POST` | `/public/telegram/webhook` | `X-Telegram-Bot-Api-Secret-Token` header | Telegram update receiver |

---

## DATA/

Seed data for the BIN (Bank Identification Number) lookup feature.

```
DATA/
├── bin-list-data.csv                   # Full BIN dataset
├── bin-list-data-US.csv                # US cards only
├── bin-list-data-US-credit.csv         # US credit cards only
├── bin-list-data-US-credit-issuers.csv # US credit cards with issuer info
├── add_colors.py                       # Script to enrich data with brand colours
├── cards/                              # Per-issuer card assets
└── sql/                                # SQL import scripts
```
