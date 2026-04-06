package com.credtrack.backend.service;

/**
 * Maps any issuer name string — from our BIN DB, an external BIN API,
 * or user input — to a stable bank_key used for card product lookup and logo display.
 *
 * Keyword matching is intentionally broad so new issuer name variants
 * from external sources resolve correctly without code changes.
 */
public final class IssuerKeyResolver {

    private IssuerKeyResolver() {}

    public static String resolve(String issuerName) {
        if (issuerName == null) return null;
        String u = issuerName.toUpperCase();

        if (u.contains("CHASE") || u.contains("JPMORGAN") || u.contains("JP MORGAN"))
            return "CHASE";
        if (u.contains("AMERICAN EXPRESS") || u.equals("AMEX"))
            return "AMEX";
        if (u.startsWith("CITIBANK") || u.startsWith("CITI ") || u.equals("CITI") || u.contains("CITICORP"))
            return "CITI";
        if (u.contains("CAPITAL ONE"))
            return "CAPITAL_ONE";
        if (u.contains("BANK OF AMERICA"))
            return "BOA";
        if (u.contains("WELLS FARGO"))
            return "WELLS_FARGO";
        if ((u.contains("DISCOVER")) && !u.contains("DISCOVERY"))
            return "DISCOVER";
        if (u.contains("U.S. BANK") || u.contains("US BANK") || u.contains("U.S.BANK"))
            return "US_BANK";
        if (u.contains("BARCLAYS"))
            return "BARCLAYS";
        if (u.contains("GOLDMAN SACHS"))
            return "GOLDMAN";
        if (u.contains("NAVY FEDERAL"))
            return "NAVY_FEDERAL";
        if (u.contains("SYNCHRONY"))
            return "SYNCHRONY";

        return null; // unknown issuer — no card products to show
    }
}
