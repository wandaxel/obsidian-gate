// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ObsidianGateMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GatePrototype", targets: ["GatePrototype"]),
        .library(name: "GateCore", targets: ["GateCore"]),
        .library(name: "GateHardware", targets: ["GateHardware"]),
        .library(name: "GateSecurity", targets: ["GateSecurity"])
    ],
    targets: [
        .executableTarget(
            name: "GatePrototype",
            dependencies: ["GateCore", "GateHardware", "GateSecurity"]
        ),
        .target(name: "GateCore"),
        .target(name: "GateHardware", dependencies: ["GateCore"]),
        .target(name: "GateSecurity", dependencies: ["GateCore"]),
        .testTarget(name: "GateCoreTests", dependencies: ["GateCore"]),
        .testTarget(name: "GateSecurityTests", dependencies: ["GateSecurity"])
    ]
)
