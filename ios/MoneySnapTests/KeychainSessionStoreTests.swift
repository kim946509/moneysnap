import Foundation
import Security
import Testing
@testable import MoneySnap

struct KeychainSessionStoreTests {
    @Test
    func savesAndLoadsTheSessionFromKeychain() async throws {
        let store = KeychainSessionStore(service: "com.ansandy.moneysnap.tests.\(UUID())")
        let expected = AuthenticationSession.keychainFixture

        try await store.save(expected)
        let loaded = try await store.load()
        try await store.clear()

        #expect(loaded == expected)
    }

    @Test
    func clearsTheSessionFromKeychain() async throws {
        let store = KeychainSessionStore(service: "com.ansandy.moneysnap.tests.\(UUID())")
        try await store.save(.keychainFixture)

        try await store.clear()

        #expect(try await store.load() == nil)
    }

    @Test
    func storesTheSessionAsDeviceOnlyAndUnlockedOnly() async throws {
        let service = "com.ansandy.moneysnap.tests.\(UUID())"
        let store = KeychainSessionStore(service: service)
        try await store.save(.keychainFixture)
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "session",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as CFDictionary, &result)
        let attributes = try #require(result as? [String: Any])
        try await store.clear()

        #expect(
            status == errSecSuccess
                && attributes[kSecAttrAccessible as String] as? String
                    == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
    }
}

private extension AuthenticationSession {
    static let keychainFixture = AuthenticationSession(
        accessToken: "keychain-access-token",
        accessExpiresAt: Date(timeIntervalSince1970: 1_900_000_000),
        refreshToken: "keychain-refresh-token",
        refreshExpiresAt: Date(timeIntervalSince1970: 2_000_000_000)
    )
}
