package com.ansandy.moneysnap.snap;

record KrwAmount(long value) {

    KrwAmount {
        if (value < 1 || value > 999_999_999) {
            throw new IllegalArgumentException("Snap amount must be between 1 and 999999999 KRW");
        }
    }
}
