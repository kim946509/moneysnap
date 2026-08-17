package com.ansandy.moneysnap.snap;

import java.net.URI;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ansandy.moneysnap.shared.AuthenticatedUser;

import tools.jackson.databind.JsonNode;

@RestController
@RequestMapping("/api/v1/snaps")
class SnapRecordController {

    private final SnapJournal journal;

    SnapRecordController(SnapJournal journal) {
        this.journal = journal;
    }

    @PostMapping
    ResponseEntity<SnapRecordReceipt> record(
            Authentication authentication,
            @Valid @RequestBody SnapRecordRequest request) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        SnapRecordReceipt receipt = journal.record(actor.userId(), request.toCommand());
        return ResponseEntity.created(URI.create("/api/v1/snaps/" + receipt.id())).body(receipt);
    }

    @GetMapping("/today")
    TodaySnapshot today(Authentication authentication, @RequestParam String timeZone) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return journal.today(actor.userId(), timeZone);
    }

    @GetMapping("/archive")
    ArchivePage archive(
            Authentication authentication,
            @RequestParam LocalDate fromLocalDay,
            @RequestParam LocalDate toLocalDay,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) String cursor) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return journal.archive(actor.userId(), fromLocalDay, toLocalDay, limit, cursor);
    }

    @GetMapping("/{snapId}")
    SnapDetail get(Authentication authentication, @PathVariable UUID snapId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return journal.get(actor.userId(), snapId);
    }

    @PatchMapping("/{snapId}")
    SnapDetail revise(
            Authentication authentication,
            @PathVariable UUID snapId,
            @Valid @RequestBody SnapReviseRequest request) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return journal.revise(actor.userId(), snapId, request.toCommand());
    }

    @DeleteMapping("/{snapId}")
    ResponseEntity<Void> delete(
            Authentication authentication,
            @PathVariable UUID snapId,
            @RequestHeader("X-Client-Mutation-Id") String clientMutationId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        journal.delete(actor.userId(), snapId, clientMutationId);
        return ResponseEntity.noContent().build();
    }

    private record SnapRecordRequest(
            @NotNull JsonNode clientMutationId,
            @NotNull JsonNode localDay,
            @NotNull JsonNode timeZone,
            @NotNull JsonNode category,
            @NotNull JsonNode amountWon,
            JsonNode imageRef) {

        @JsonAnySetter
        void rejectUnknownProperty(String name, Object value) {
            throw new IllegalArgumentException("Unknown Snap command property");
        }

        SnapRecordCommand toCommand() {
            return new SnapRecordCommand(
                    requireString(clientMutationId),
                    requireLocalDate(localDay),
                    requireString(timeZone),
                    SnapCategory.fromCode(requireString(category)),
                    requireAmount(amountWon),
                    requireImageRef(imageRef));
        }

        private static String requireString(JsonNode value) {
            if (!value.isString()) {
                throw new IllegalArgumentException("Snap command field must be a JSON string");
            }
            return value.stringValue();
        }

        private static LocalDate requireLocalDate(JsonNode value) {
            try {
                return LocalDate.parse(requireString(value));
            }
            catch (DateTimeParseException exception) {
                throw new IllegalArgumentException("localDay must be an ISO date", exception);
            }
        }

        private static UUID requireImageRef(JsonNode value) {
            if (value == null || value.isNull() || value.isMissingNode()) {
                return null;
            }
            if (!value.isString()) {
                throw new IllegalArgumentException("imageRef must be a JSON string");
            }
            try {
                return UUID.fromString(value.stringValue());
            }
            catch (IllegalArgumentException exception) {
                throw new IllegalArgumentException("imageRef must be a UUID", exception);
            }
        }

        private static KrwAmount requireAmount(JsonNode value) {
            if (!value.isIntegralNumber() || !value.canConvertToLong()) {
                throw new IllegalArgumentException("amountWon must be an integer JSON number");
            }
            return new KrwAmount(value.longValue());
        }
    }

    private record SnapReviseRequest(
            @NotNull JsonNode clientMutationId,
            @NotNull JsonNode expectedVersion,
            @NotNull JsonNode category,
            @NotNull JsonNode amountWon) {

        @JsonAnySetter
        void rejectUnknownProperty(String name, Object value) {
            throw new IllegalArgumentException("Unknown Snap command property");
        }

        SnapReviseCommand toCommand() {
            return new SnapReviseCommand(
                    SnapRecordRequest.requireString(clientMutationId),
                    requireVersion(expectedVersion),
                    SnapCategory.fromCode(SnapRecordRequest.requireString(category)),
                    SnapRecordRequest.requireAmount(amountWon));
        }

        private static int requireVersion(JsonNode value) {
            if (!value.isIntegralNumber() || !value.canConvertToInt()) {
                throw new IllegalArgumentException("expectedVersion must be an integer JSON number");
            }
            return value.intValue();
        }
    }
}
