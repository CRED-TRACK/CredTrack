-- Import issuers
-- Run from the repo root: psql -U postgres -d credtrack -f DATA/sql/import_data.sql
\copy issuers(issuer_name, issuer_phone, issuer_url, color) FROM 'DATA/bin-list-data-US-credit-issuers.csv' CSV HEADER;

-- Import BIN records
\copy bin_records(bin, brand, type, category, issuer, issuer_phone, issuer_url, iso_code_2, iso_code_3, country_name, color) FROM 'DATA/bin-list-data-US-credit.csv' CSV HEADER;
