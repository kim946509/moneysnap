package com.ansandy.moneysnap.shared;

import java.util.UUID;

public interface AccountMediaCleanup {

    void transferToTombstones(UUID userId);
}
