import XCTest
@testable import GateSecurity

final class TouchIDPolicyTests: XCTestCase {
    func testAuthenticatorCanBeConstructedWithoutPrompting() {
        // Hardware-dependent authentication is intentionally not triggered in CI.
        _ = TouchIDAuthenticator()
        XCTAssertTrue(true)
    }
}
