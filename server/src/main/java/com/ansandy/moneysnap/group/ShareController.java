package com.ansandy.moneysnap.group;

import java.net.URI;
import java.util.UUID;

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
@RequestMapping("/api/v1/shares")
class ShareController {

    private final GroupSharing groups;

    ShareController(GroupSharing groups) {
        this.groups = groups;
    }

    @PostMapping
    ResponseEntity<ShareRecord> share(
            Authentication authentication,
            @Valid @RequestBody ShareRequest request) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        ShareRecord created = groups.share(actor.userId(), request.toCommand());
        return ResponseEntity.created(URI.create("/api/v1/shares/" + created.id())).body(created);
    }

    private record ShareRequest(
            @NotNull JsonNode clientMutationId,
            @NotNull JsonNode snapId,
            @NotNull JsonNode groupId) {

        @JsonAnySetter
        void rejectUnknownProperty(String name, Object value) {
            throw new IllegalArgumentException("Unknown share command property");
        }

        ShareCommand toCommand() {
            if (!clientMutationId.isString() || !snapId.isString() || !groupId.isString()) {
                throw new IllegalArgumentException("Share fields must be JSON strings");
            }
            return new ShareCommand(
                    clientMutationId.stringValue(),
                    UUID.fromString(snapId.stringValue()),
                    UUID.fromString(groupId.stringValue()));
        }
    }
}
