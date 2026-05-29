package com.credtrack.backend.entity;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

public enum CanonicalCategory {
    GROCERIES_SUPERMARKETS("Groceries", "cart.fill",
        List.of("Whole Foods", "Trader Joe's", "Safeway", "Kroger", "Publix", "Wegmans")),
    WAREHOUSE_CLUB("Warehouse Club", "shippingbox.fill",
        List.of("Costco", "Sam's Club", "BJ's Wholesale")),
    DINING_RESTAURANTS("Dining", "fork.knife",
        List.of("Chipotle", "Starbucks", "Sweetgreen", "local restaurants")),
    FAST_FOOD("Fast Food & Delivery", "takeoutbag.and.cup.and.straw.fill",
        List.of("McDonald's", "DoorDash", "Uber Eats", "Grubhub")),
    GAS_STATIONS("Gas", "fuelpump.fill",
        List.of("Shell", "Chevron", "Exxon", "Mobil", "BP")),
    EV_CHARGING("EV Charging", "bolt.car.fill",
        List.of("Tesla Supercharger", "Electrify America", "ChargePoint")),
    ONLINE_RETAIL("Online Shopping", "bag.fill",
        List.of("Amazon", "Target.com", "Best Buy online", "eBay")),
    DRUGSTORES("Drugstores", "cross.case.fill",
        List.of("CVS", "Walgreens", "Rite Aid")),
    TRAVEL_GENERAL("Travel", "airplane",
        List.of("airlines", "hotels", "car rentals")),
    TRAVEL_PORTAL("Travel via Issuer Portal", "globe.americas.fill",
        List.of("Chase Travel", "Amex Travel", "Capital One Travel")),
    HOTELS("Hotels", "bed.double.fill",
        List.of("Marriott", "Hilton", "Hyatt", "IHG")),
    AIRLINES("Airlines", "airplane.departure",
        List.of("Delta", "United", "American", "Southwest", "JetBlue")),
    RIDESHARE("Rideshare", "car.fill",
        List.of("Uber", "Lyft")),
    STREAMING("Streaming", "play.tv.fill",
        List.of("Netflix", "Disney+", "Hulu", "Spotify", "Apple TV+")),
    UTILITIES("Utilities", "bolt.fill",
        List.of("Eversource", "ConEd", "Verizon", "Comcast", "PG&E")),
    TRANSIT("Transit", "tram.fill",
        List.of("MTA", "BART", "WMATA", "MBTA")),
    ENTERTAINMENT("Entertainment", "ticket.fill",
        List.of("AMC", "movie theaters", "concerts", "Ticketmaster")),
    HOME_IMPROVEMENT("Home Improvement", "hammer.fill",
        List.of("Home Depot", "Lowe's", "Ace Hardware")),
    DEPARTMENT_STORES("Department Stores", "building.2.fill",
        List.of("Macy's", "Nordstrom", "Kohl's")),
    OTHER("Other", "creditcard.fill", List.of());

    private final String displayName;
    private final String iconHint;
    private final List<String> commonMerchants;

    CanonicalCategory(String displayName, String iconHint, List<String> commonMerchants) {
        this.displayName = displayName;
        this.iconHint = iconHint;
        this.commonMerchants = commonMerchants;
    }

    public String code() { return name(); }
    public String displayName() { return displayName; }
    public String iconHint() { return iconHint; }
    public List<String> commonMerchants() { return commonMerchants; }

    public static Optional<CanonicalCategory> fromCode(String code) {
        if (code == null) return Optional.empty();
        return Arrays.stream(values()).filter(c -> c.name().equalsIgnoreCase(code)).findFirst();
    }
}
