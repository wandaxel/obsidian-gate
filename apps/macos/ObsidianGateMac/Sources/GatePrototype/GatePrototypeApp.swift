import SwiftUI
import GateCore
import GateHardware
import GateSecurity

@main
struct GatePrototypeApp: App {
    var body: some Scene {
        WindowGroup("Obsidian Gate — Prototype") {
            GateDemoView()
                .frame(minWidth: 520, minHeight: 420)
        }
    }
}

@MainActor
final class GateDemoModel: ObservableObject {
    @Published private(set) var state: GateState = .locked
    @Published var usbStatus = "Surveillance USB non démarrée"
    @Published var lastDevice = "Aucun périphérique détecté"
    @Published var message = "Connecte le Chameleon, puis lance la démo du parcours."

    private let machine = GateStateMachine(unlockDuration: 120)
    private let authenticator = TouchIDAuthenticator()
    private var monitor: USBDeviceMonitor?

    func startUSBMonitoring() {
        guard monitor == nil else { return }
        let newMonitor = USBDeviceMonitor { [weak self] device, connected in
            DispatchQueue.main.async {
                guard let self else { return }
                self.lastDevice = device.diagnosticDescription
                self.usbStatus = connected ? "Périphérique USB connecté" : "Périphérique USB déconnecté"
                if !connected {
                    try? self.machine.send(.usbDisconnected)
                    self.state = self.machine.state
                    self.message = "Déconnexion USB : le Gate revient à l’état verrouillé."
                }
            }
        }
        do {
            try newMonitor.start()
            monitor = newMonitor
            usbStatus = "Surveillance USB active"
        } catch {
            usbStatus = "Erreur IOKit : \(error.localizedDescription)"
        }
    }

    func stopUSBMonitoring() {
        monitor?.stop()
        monitor = nil
        usbStatus = "Surveillance USB arrêtée"
    }

    func simulateBadgeAndChallenge() {
        do {
            try machine.send(.badgeDetected)
            let challengeID = UUID()
            try machine.send(.challengePresented(id: challengeID))
            state = machine.state
            message = "Badge simulé : défi présenté. La présence USB seule ne valide pas un badge."
        } catch {
            message = "Transition refusée : \(error)"
        }
    }

    func acceptDemoAnswerAndRequestTouchID() {
        do {
            try machine.send(.answerAccepted)
            state = machine.state
            message = "Réponse de démonstration acceptée. Touch ID demandé…"
            authenticator.authenticate(reason: "Confirmer le déverrouillage temporaire d’Obsidian Gate") { [weak self] result in
                guard let self else { return }
                switch result {
                case .authenticated:
                    try? self.machine.send(.biometricSucceeded)
                    self.message = "Authentification biométrique réussie."
                case .rejected:
                    try? self.machine.send(.biometricFailed)
                    self.message = "Authentification annulée."
                case .unavailable(let reason), .failed(let reason):
                    try? self.machine.send(.biometricFailed)
                    self.message = "Touch ID indisponible ou en échec : \(reason)"
                }
                self.state = self.machine.state
            }
        } catch {
            message = "Action impossible dans cet état : \(error)"
        }
    }

    func lock() {
        try? machine.send(.cancelled)
        machine.expireIfNeeded(now: .distantFuture)
        state = machine.state
        message = "Gate verrouillé."
    }
}

struct GateDemoView: View {
    @StateObject private var model = GateDemoModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OBSIDIAN GATE").font(.largeTitle.bold())
            Text("Prototype macOS · Touch ID · USB · machine à états")
                .foregroundStyle(.secondary)

            GroupBox("État du Gate") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(describing: model.state))
                        .font(.headline.monospaced())
                    Text(model.message).font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Détection USB") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.usbStatus)
                    Text(model.lastDevice).font(.caption.monospaced())
                    HStack {
                        Button("Démarrer la surveillance") { model.startUSBMonitoring() }
                        Button("Arrêter") { model.stopUSBMonitoring() }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Parcours de démonstration") {
                VStack(alignment: .leading, spacing: 10) {
                    Button("1 · Simuler un badge et présenter le défi") {
                        model.simulateBadgeAndChallenge()
                    }
                    Button("2 · Valider la réponse et demander Touch ID") {
                        model.acceptDemoAnswerAndRequestTouchID()
                    }
                    Button("Verrouiller le Gate") { model.lock() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Important : ce prototype déverrouille uniquement son état applicatif. Il ne déverrouille jamais la session macOS. La présence USB n’est pas une preuve d’identité et le protocole RFID Chameleon reste à intégrer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .onAppear { model.startUSBMonitoring() }
        .onDisappear { model.stopUSBMonitoring() }
    }
}
