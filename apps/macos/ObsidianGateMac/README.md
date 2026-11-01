# Obsidian Gate — macOS prototype

This Swift Package contains isolated macOS prototypes for Touch ID, USB discovery and the Gate flow.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools / Swift 5.9+
- A Mac with Touch ID for the biometric hardware check
- Chameleon Ultra connected over USB for the device-discovery check

## Build and test

From this directory:

```sh
swift test
swift build
swift run GatePrototype
```

`GatePrototype` opens a small SwiftUI window. It starts USB monitoring on launch, lets you simulate the badge/challenge step, and invokes the real Touch ID prompt only after the demo answer is accepted. The answer itself is simulated; the Chameleon RFID protocol is not yet connected.

The package is macOS-only because it imports LocalAuthentication and IOKit.

## Touch ID

`GateSecurity/TouchIDAuthenticator` calls `canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`, checks that the reported biometric type is Touch ID, and then evaluates the policy. It deliberately does not enable passcode fallback. The caller must treat every result other than `authenticated` as a failed Gate step. No biometric template or secret is read or stored.

## USB discovery

`GateHardware/USBDeviceMonitor` observes IOUSBHostDevice arrival and removal notifications. It reports VID, PID, product name and serial number when the operating system exposes them. An optional vendor-ID allowlist can narrow events after the real Chameleon V3 VID/PID has been confirmed on the target machine.

This is USB device discovery only. It does not yet speak the Chameleon serial/CLI protocol, scan RFID cards, or infer a device's identity from its USB name. The Chameleon VID/PID is intentionally not guessed.

## Gate flow and security invariants

`GateCore/GateStateMachine` enforces:

1. A badge-presence event starts a challenge; a UID is not accepted as proof of identity.
2. Only an accepted challenge answer can request biometrics.
3. Only successful biometrics can enter the app's temporary unlocked state.
4. Rejection, cancellation, USB removal and inactivity expiry return the Gate to locked.
5. The unlock state is app-local. It does not unlock macOS, loginwindow, FileVault or the screen saver session.

The default temporary unlock duration is 120 seconds. This is an initial prototype default, not a final product decision.

## Hardware validation still required

- Capture the Chameleon V3 VID/PID and USB registry properties on the actual Mac.
- Confirm whether the installed firmware exposes the expected USB interface and select the documented CLI/SDK/protocol.
- Test hot-plug and removal while each Gate state is active.
- Run `swift test` and `swift build` on macOS; this repository's GitHub editing integration cannot execute these commands.
