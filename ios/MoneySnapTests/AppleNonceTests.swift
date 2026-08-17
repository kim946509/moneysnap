import Testing
@testable import MoneySnap

struct AppleNonceTests {
    @Test
    func hashesTheNonceWithSHA256() {
        #expect(AppleNonce.hash("request-nonce") == "727e77cae7f89d57cb097b3ddcf620b00abc397d1984003bf453f08324342110")
    }

    @Test
    func generatesA256BitHexNonce() throws {
        let nonce = try AppleNonce.make()

        #expect(nonce.count == 64 && nonce.allSatisfy(\.isHexDigit))
    }

    @Test
    func separatesTheRawServerNonceFromTheHashedAppleRequestNonce() throws {
        let challenge = try AppleNonce.challenge()

        #expect(
            challenge.appleRequestNonce == AppleNonce.hash(challenge.serverNonce)
                && challenge.appleRequestNonce != challenge.serverNonce
        )
    }
}
