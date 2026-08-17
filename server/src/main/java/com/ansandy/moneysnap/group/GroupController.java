package com.ansandy.moneysnap.group;

import java.net.URI;
import java.util.List;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
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
@RequestMapping("/api/v1/groups")
class GroupController {

    private final GroupSharing groups;

    GroupController(GroupSharing groups) {
        this.groups = groups;
    }

    @PostMapping
    ResponseEntity<GroupRecord> create(
            Authentication authentication,
            @Valid @RequestBody GroupCreateRequest request) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        GroupRecord created = groups.create(actor.userId(), request.toCommand());
        return ResponseEntity.created(URI.create("/api/v1/groups/" + created.id())).body(created);
    }

    @GetMapping
    GroupList list(Authentication authentication) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return new GroupList(groups.list(actor.userId()));
    }

    @GetMapping("/{groupId}")
    GroupRecord get(Authentication authentication, @PathVariable UUID groupId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return groups.get(actor.userId(), groupId);
    }

    @PostMapping("/{groupId}/invites")
    IssuedInvite issueInvite(Authentication authentication, @PathVariable UUID groupId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return groups.issueInvite(actor.userId(), groupId);
    }

    @DeleteMapping("/{groupId}/invites")
    ResponseEntity<Void> revokeInvite(Authentication authentication, @PathVariable UUID groupId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        groups.revokeInvite(actor.userId(), groupId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{groupId}/members")
    MemberList members(Authentication authentication, @PathVariable UUID groupId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return new MemberList(groups.members(actor.userId(), groupId));
    }

    @DeleteMapping("/{groupId}/members/me")
    ResponseEntity<Void> leave(Authentication authentication, @PathVariable UUID groupId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        groups.leave(actor.userId(), groupId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{groupId}/members/{memberId}")
    ResponseEntity<Void> removeMember(
            Authentication authentication,
            @PathVariable UUID groupId,
            @PathVariable UUID memberId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        groups.removeMember(actor.userId(), groupId, memberId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{groupId}/today")
    Object today(
            Authentication authentication,
            @PathVariable UUID groupId,
            @RequestParam String timeZone) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return groups.today(actor.userId(), groupId, timeZone);
    }

    @GetMapping("/{groupId}/members/{memberId}/today")
    Object memberToday(
            Authentication authentication,
            @PathVariable UUID groupId,
            @PathVariable UUID memberId,
            @RequestParam String timeZone) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return groups.memberToday(actor.userId(), groupId, memberId, timeZone);
    }

    @DeleteMapping("/{groupId}")
    ResponseEntity<Void> delete(
            Authentication authentication,
            @PathVariable UUID groupId,
            @RequestHeader("X-Client-Mutation-Id") String clientMutationId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        groups.delete(actor.userId(), groupId, clientMutationId);
        return ResponseEntity.noContent().build();
    }

    private record GroupCreateRequest(
            @NotNull JsonNode clientMutationId,
            @NotNull JsonNode name,
            @NotNull JsonNode amountVisible) {

        @JsonAnySetter
        void rejectUnknownProperty(String name, Object value) {
            throw new IllegalArgumentException("Unknown group command property");
        }

        GroupCreateCommand toCommand() {
            if (!clientMutationId.isString()) {
                throw new IllegalArgumentException("clientMutationId must be a JSON string");
            }
            if (!name.isString()) {
                throw new IllegalArgumentException("name must be a JSON string");
            }
            if (!amountVisible.isBoolean()) {
                throw new IllegalArgumentException("amountVisible must be a JSON boolean");
            }
            return new GroupCreateCommand(
                    clientMutationId.stringValue(),
                    new GroupName(name.stringValue()),
                    amountVisible.booleanValue());
        }
    }
}
