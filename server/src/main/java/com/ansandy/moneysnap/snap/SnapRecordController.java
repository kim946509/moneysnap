package com.ansandy.moneysnap.snap;

import java.net.URI;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
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

    private record SnapRecordRequest(
            @NotNull JsonNode clientMutationId,
            @NotNull JsonNode localDay,
            @NotNull JsonNode timeZone,
            @NotNull JsonNode category,
            @NotNull JsonNode amountWon) {

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
                    requireAmount(amountWon));
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

        private static KrwAmount requireAmount(JsonNode value) {
            if (!value.isIntegralNumber() || !value.canConvertToLong()) {
                throw new IllegalArgumentException("amountWon must be an integer JSON number");
            }
            return new KrwAmount(value.longValue());
        }
    }
}
