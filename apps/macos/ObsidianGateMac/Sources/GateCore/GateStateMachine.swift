import Foundation

/// Application-level gate states. This state machine never controls macOS loginwindow.
public enum GateState: Equatable {
    case locked
    case awaitingChallenge
    case awaitingAnswer(challengeID: UUID)
    case awaitingBiometrics
    case unlocked(until: Date)
}

public enum GateEvent {
    case badgeDetected
    case challengePresented(id: UUID)
    case answerAccepted
    case answerRejected
    case biometricSucceeded
    case biometricFailed
    case cancelled
    case usbDisconnected
    case inactivityTimeout
}

public enum GateTransitionError: Error, Equatable {
    case invalidTransition(state: GateStateName, event: GateEventName)
}

public enum GateStateName: String {
    case locked, awaitingChallenge, awaitingAnswer, awaitingBiometrics, unlocked
}

public enum GateEventName: String {
    case badgeDetected, challengePresented, answerAccepted, answerRejected
    case biometricSucceeded, biometricFailed, cancelled, usbDisconnected, inactivityTimeout
}

public final class GateStateMachine {
    public private(set) var state: GateState = .locked
    private let unlockDuration: TimeInterval

    public init(unlockDuration: TimeInterval = 120) {
        self.unlockDuration = max(1, unlockDuration)
    }

    @discardableResult
    public func send(_ event: GateEvent, now: Date = Date()) throws -> GateState {
        switch (state, event) {
        case (.locked, .badgeDetected):
            state = .awaitingChallenge
        case (.awaitingChallenge, .challengePresented(let id)):
            state = .awaitingAnswer(challengeID: id)
        case (.awaitingAnswer, .answerAccepted):
            state = .awaitingBiometrics
        case (.awaitingAnswer, .answerRejected),
             (.awaitingChallenge, .cancelled),
             (.awaitingAnswer, .cancelled),
             (.awaitingBiometrics, .cancelled),
             (.awaitingBiometrics, .biometricFailed),
             (.awaitingChallenge, .usbDisconnected),
             (.awaitingAnswer, .usbDisconnected),
             (.awaitingBiometrics, .usbDisconnected),
             (.unlocked, .usbDisconnected),
             (.unlocked, .inactivityTimeout):
            state = .locked
        case (.awaitingBiometrics, .biometricSucceeded):
            state = .unlocked(until: now.addingTimeInterval(unlockDuration))
        case (.unlocked(let deadline), _) where now >= deadline:
            state = .locked
            if case .badgeDetected = event {
                state = .awaitingChallenge
            } else {
                throw invalid(event)
            }
        default:
            throw invalid(event)
        }
        return state
    }

    /// Call on foreground/resume as well as from the app's inactivity timer.
    public func expireIfNeeded(now: Date = Date()) {
        if case .unlocked(let deadline) = state, now >= deadline {
            state = .locked
        }
    }

    private func invalid(_ event: GateEvent) -> GateTransitionError {
        GateTransitionError.invalidTransition(state: stateName, event: event.name)
    }

    private var stateName: GateStateName {
        switch state {
        case .locked: .locked
        case .awaitingChallenge: .awaitingChallenge
        case .awaitingAnswer: .awaitingAnswer
        case .awaitingBiometrics: .awaitingBiometrics
        case .unlocked: .unlocked
        }
    }
}

private extension GateEvent {
    var name: GateEventName {
        switch self {
        case .badgeDetected: .badgeDetected
        case .challengePresented: .challengePresented
        case .answerAccepted: .answerAccepted
        case .answerRejected: .answerRejected
        case .biometricSucceeded: .biometricSucceeded
        case .biometricFailed: .biometricFailed
        case .cancelled: .cancelled
        case .usbDisconnected: .usbDisconnected
        case .inactivityTimeout: .inactivityTimeout
        }
    }
}
