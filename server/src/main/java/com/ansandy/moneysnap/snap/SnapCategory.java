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
}
