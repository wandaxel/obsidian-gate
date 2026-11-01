import Foundation
import LocalAuthentication

public enum TouchIDResult {
    case authenticated
    case rejected
    case unavailable(reason: String)
    case failed(reason: String)
}

public protocol BiometricAuthenticating {
    func authenticate(reason: String, completion: @escaping (TouchIDResult) -> Void)
}

/// Touch ID only: no password/passcode fallback is silently enabled.
public final class TouchIDAuthenticator: BiometricAuthenticating {
    public init() {}

    public func authenticate(reason: String, completion: @escaping (TouchIDResult) -> Void) {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        context.localizedCancelTitle = NSLocalizedString("Cancel", comment: "Cancel Touch ID prompt")

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            completion(.unavailable(reason: Self.message(for: policyError)))
            return
        }

        guard context.biometryType == .touchID else {
            completion(.unavailable(reason: "Touch ID is not available on this Mac."))
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.authenticated)
                } else if let laError = error as? LAError, laError.code == .userCancel || laError.code == .appCancel || laError.code == .systemCancel {
                    completion(.rejected)
                } else {
                    completion(.failed(reason: Self.message(for: error as NSError?)))
                }
            }
        }
    }

    private static func message(for error: NSError?) -> String {
        guard let error else { return "Biometric authentication is unavailable." }
        return error.localizedDescription
    }
}
