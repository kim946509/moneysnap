package com.ansandy.moneysnap.group;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ansandy.moneysnap.shared.AuthenticatedUser;

import tools.jackson.databind.JsonNode;

@RestController
@RequestMapping("/api/v1/invites")
class InviteController {

    private final GroupSharing groups;

    InviteController(GroupSharing groups) {
        this.groups = groups;
    }

    @PostMapping("/preview")
    InvitePreview preview(@Valid @RequestBody InviteCodeRequest request) {
        return groups.previewInvite(request.requireCode());
    }

    @PostMapping("/join")
    GroupRecord join(Authentication authentication, @Valid @RequestBody JoinRequest request) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return groups.join(actor.userId(), request.requireCode(), request.requireMutationId());
    }

    private record InviteCodeRequest(@NotNull JsonNode code) {

        @JsonAnySetter
        void rejectUnknownProperty(String name, Object value) {
            throw new IllegalArgumentException("Unknown invite property");
        }

        String requireCode() {
            if (!code.isString()) {
                throw new IllegalArgumentException("code must be a JSON string");
            }
            return code.stringValue();
        }
    }

    private record JoinRequest(@NotNull JsonNode code, @NotNull JsonNode clientMutationId) {

        @JsonAnySetter
        void rejectUnknownProperty(String name, Object value) {
            throw new IllegalArgumentException("Unknown invite property");
        }

        String requireCode() {
            if (!code.isString()) {
                throw new IllegalArgumentException("code must be a JSON string");
            }
            return code.stringValue();
        }

        String requireMutationId() {
            if (!clientMutationId.isString()) {
                throw new IllegalArgumentException("clientMutationId must be a JSON string");
            }
            return clientMutationId.stringValue();
        }
    }
}
