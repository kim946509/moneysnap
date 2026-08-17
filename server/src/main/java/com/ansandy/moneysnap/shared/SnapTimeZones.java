package com.ansandy.moneysnap.shared;

import java.time.ZoneId;
import java.time.ZoneOffset;

public final class SnapTimeZones {

    private SnapTimeZones() {
    }

    public static ZoneId requireRegionOrUtc(String timeZone) {
        if ("UTC".equals(timeZone)) {
            return ZoneOffset.UTC;
        }
        if (timeZone == null || timeZone.isBlank()
                || !timeZone.contains("/")
                || !ZoneId.getAvailableZoneIds().contains(timeZone)) {
            throw new IllegalArgumentException("timeZone must be a tzdb region or UTC");
        }
        return ZoneId.of(timeZone);
    }
}
