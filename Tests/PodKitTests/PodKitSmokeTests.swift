import Testing
@testable import PodKit

/// Keeps the test target non-empty on its own. SPM rejects a declared target
/// whose directory is missing, and git does not track an empty one, so
/// without this the package does not build from a clean checkout.
@Suite("Package smoke")
struct PodKitSmokeTests {
    @Test("The version is a three-part semantic version")
    func versionIsSemantic() {
        let parts = Pod.version.split(separator: ".")

        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
