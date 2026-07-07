import Testing
@testable import SolytiqCloudMobile

struct KeychainStoreTests {
    @Test func setAndGetRoundTrips() {
        let key = "test.roundtrip"
        defer { KeychainStore.remove(key) }
        KeychainStore.set("hello-world", for: key)
        #expect(KeychainStore.get(key) == "hello-world")
    }

    @Test func overwriteReplacesPreviousValue() {
        let key = "test.overwrite"
        defer { KeychainStore.remove(key) }
        KeychainStore.set("first", for: key)
        KeychainStore.set("second", for: key)
        #expect(KeychainStore.get(key) == "second")
    }

    @Test func removeClearsValue() {
        let key = "test.remove"
        KeychainStore.set("value", for: key)
        KeychainStore.remove(key)
        #expect(KeychainStore.get(key) == nil)
    }

    @Test func missingKeyReturnsNil() {
        #expect(KeychainStore.get("test.neverSet") == nil)
    }
}
