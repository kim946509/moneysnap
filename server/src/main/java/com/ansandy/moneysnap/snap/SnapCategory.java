package com.ansandy.moneysnap.snap;

enum SnapCategory {
    FOOD("food"),
    CAFE("cafe"),
    TRANSPORTATION("transportation"),
    SHOPPING("shopping"),
    LIVING("living"),
    CULTURE("culture"),
    HEALTH("health"),
    OTHER("other");

    private final String code;

    SnapCategory(String code) {
        this.code = code;
    }

    String code() {
        return code;
    }

    static SnapCategory fromCode(String code) {
        for (SnapCategory category : values()) {
            if (category.code.equals(code)) {
                return category;
            }
        }
        throw new IllegalArgumentException("Unknown Snap category");
    }
}
