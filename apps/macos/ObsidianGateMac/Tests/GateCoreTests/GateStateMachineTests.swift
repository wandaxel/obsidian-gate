import XCTest
@testable import GateCore

final class GateStateMachineTests: XCTestCase {
    func testHappyPathRequiresChallengeAnswerAndBiometrics() throws {
        let machine = GateStateMachine(unlockDuration: 60)
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(try machine.send(.badgeDetected, now: now), .awaitingChallenge)
        XCTAssertEqual(try machine.send(.challengePresented(id: UUID()), now: now), .awaitingAnswer(challengeID: {
            if case .awaitingAnswer(let id) = machine.state { return id }
            return UUID()
        }()))
        XCTAssertEqual(try machine.send(.answerAccepted, now: now), .awaitingBiometrics)
        XCTAssertEqual(try machine.send(.biometricSucceeded, now: now), .unlocked(until: now.addingTimeInterval(60)))
    }

    func testBiometricsCannotUnlockBeforeCorrectAnswer() {
        let machine = GateStateMachine()
        XCTAssertThrowsError(try machine.send(.biometricSucceeded))
        XCTAssertEqual(machine.state, .locked)
    }

    func testWrongAnswerReturnsToLocked() throws {
        let machine = GateStateMachine()
        try machine.send(.badgeDetected)
        try machine.send(.challengePresented(id: UUID()))
        XCTAssertEqual(try machine.send(.answerRejected), .locked)
    }

    func testBiometricFailureAndCancellationNeverUnlock() throws {
        let machine = GateStateMachine()
        try machine.send(.badgeDetected)
        try machine.send(.challengePresented(id: UUID()))
        try machine.send(.answerAccepted)
        XCTAssertEqual(try machine.send(.biometricFailed), .locked)
        XCTAssertThrowsError(try machine.send(.biometricSucceeded))
    }

    func testUSBRemovalAbortsAnInFlightFlow() throws {
        let machine = GateStateMachine()
        try machine.send(.badgeDetected)
        try machine.send(.challengePresented(id: UUID()))
        XCTAssertEqual(try machine.send(.usbDisconnected), .locked)
    }

    func testUnlockExpires() throws {
        let machine = GateStateMachine(unlockDuration: 5)
        let now = Date(timeIntervalSince1970: 100)
        try machine.send(.badgeDetected, now: now)
        try machine.send(.challengePresented(id: UUID()), now: now)
        try machine.send(.answerAccepted, now: now)
        try machine.send(.biometricSucceeded, now: now)
        machine.expireIfNeeded(now: now.addingTimeInterval(6))
        XCTAssertEqual(machine.state, .locked)
    }

    func testBadgeUIDIsNotAnEventOrCredential() {
        // The public state machine accepts only a presence event, never a UID/token.
        let machine = GateStateMachine()
        XCTAssertNoThrow(try machine.send(.badgeDetected))
    }
}
