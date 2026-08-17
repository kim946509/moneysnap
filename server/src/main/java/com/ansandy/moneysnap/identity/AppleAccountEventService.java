package com.ansandy.moneysnap.identity;

import java.time.Clock;
import java.util.Objects;

final class AppleAccountEventService {

	private final IdentitySessionStore store;
	private final Clock clock;

	AppleAccountEventService(IdentitySessionStore store, Clock clock) {
		this.store = Objects.requireNonNull(store);
		this.clock = Objects.requireNonNull(clock);
	}

	void handle(VerifiedAppleAccountEvent event) {
		store.applyAppleAccountEvent(Objects.requireNonNull(event), clock.instant());
	}
}
