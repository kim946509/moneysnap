package com.ansandy.moneysnap.identity;

import java.sql.Date;
import java.time.Clock;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.Objects;
import java.util.UUID;

import javax.sql.DataSource;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.core.Authentication;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ansandy.moneysnap.shared.http.ApiErrorCode;
import com.ansandy.moneysnap.shared.http.ApiErrorResponse;

import com.ansandy.moneysnap.shared.AuthenticatedUser;
import com.ansandy.moneysnap.shared.SnapTimeZones;

@RestController
@RequestMapping("/api/v1/account")
class AccountSummaryController {

    private final JdbcClient jdbc;
    private final Clock clock;

    AccountSummaryController(DataSource dataSource, Clock identityClock) {
        this.jdbc = JdbcClient.create(dataSource);
        this.clock = Objects.requireNonNull(identityClock);
    }

    @GetMapping("/summary")
    AccountSummary summary(Authentication authentication, @RequestParam String timeZone) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        ZoneId zone = com.ansandy.moneysnap.shared.SnapTimeZones.requireRegionOrUtc(timeZone);
        LocalDate today = LocalDate.ofInstant(clock.instant(), zone);
        YearMonth month = YearMonth.from(today);
        LocalDate monthStart = month.atDay(1);
        LocalDate monthEnd = month.atEndOfMonth();
        UUID userId = actor.userId();
        String displayName = jdbc.sql("SELECT display_name FROM users WHERE id = :id")
                .param("id", userId)
                .query(String.class)
                .optional()
                .orElse("MoneySnap 사용자");
        int todayCount = jdbc.sql("""
                SELECT count(*) FROM snaps
                WHERE owner_id = :ownerId AND local_day = :day
                """)
                .param("ownerId", userId)
                .param("day", Date.valueOf(today))
                .query(Integer.class)
                .single();
        int monthCount = jdbc.sql("""
                SELECT count(*) FROM snaps
                WHERE owner_id = :ownerId AND local_day BETWEEN :fromDay AND :toDay
                """)
                .param("ownerId", userId)
                .param("fromDay", Date.valueOf(monthStart))
                .param("toDay", Date.valueOf(monthEnd))
                .query(Integer.class)
                .single();
        int groupCount = jdbc.sql("""
                SELECT count(*) FROM group_memberships WHERE user_id = :userId
                """)
                .param("userId", userId)
                .query(Integer.class)
                .single();
        return new AccountSummary(displayName, todayCount, monthCount, groupCount);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ApiErrorResponse invalidRequest() {
        return ApiErrorResponse.of(ApiErrorCode.INVALID_REQUEST);
    }
}

record AccountSummary(String displayName, int todaySnapCount, int monthSnapCount, int groupCount) {
}
