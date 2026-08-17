package com.ansandy.moneysnap.snap;

final class SnapTimeZones {

    private SnapTimeZones() {
    }

    static java.time.ZoneId requireRegionOrUtc(String timeZone) {
        return com.ansandy.moneysnap.shared.SnapTimeZones.requireRegionOrUtc(timeZone);
    }
}
