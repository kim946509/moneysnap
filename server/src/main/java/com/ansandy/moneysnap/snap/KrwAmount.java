package com.ansandy.moneysnap.snap;

record KrwAmount(long value) {

    KrwAmount {
        if (value <= 0) {
            throw new IllegalArgumentException("Snap amount must be a positive KRW integer");
        }
    }
}
