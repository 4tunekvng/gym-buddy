// swift-tools-version:5.10
import PackageDescription

// Gym Buddy — Chapter 1 MVP
// Module structure follows docs/ARCHITECTURE.md. Dependency direction is enforced
// by target-level `dependencies:` declarations — the compiler will refuse to build
// if any module imports something it hasn't declared.
//
// The jewel is CoachingEngine: pure Swift, no platform imports, no vendor SDKs.
// Adapters wrap platform and vendor capabilities behind protocols that live in
// CoachingEngine, so a future swap (MediaPipe for Vision, Claude for another LLM)
// touches the adapter and nothing else.

let package = Package(
    name: "GymBuddy",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)  // so swift test can run CoachingEngine and other pure modules on macOS CI
    ],
    products: [
        .library(name: "CoachingEngine", targets: ["CoachingEngine"]),
        .library(name: "PoseVision", targets: ["PoseVision"]),
        .library(name: "VoiceIO", targets: ["VoiceIO"]),
        .library(name: "LLMClient", targets: ["LLMClient"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "HealthKitBridge", targets: ["HealthKitBridge"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Telemetry", targets: ["Telemetry"]),
        .executable(name: "coaching-cli", targets: ["CoachingCLI"])
    ],
    dependencies: [
        // Deliberately empty. If an ADR approves an external dependency, it gets added here
        // and the ADR is referenced in the comment.
    ],
    targets: [
        // MARK: - Domain (sacrosanct — only Swift stdlib + Foundation allowed)
        .target(
            name: "CoachingEngine",
            dependencies: [],
            path: "Sources/CoachingEngine"
        ),

        // MARK: - Platform + vendor adapters
        .target(
            name: "PoseVision",
            dependencies: ["CoachingEngine"],
            path: "Sources/PoseVision"
        ),
        .target(
            name: "VoiceIO",
            dependencies: ["CoachingEngine", "Telemetry"],
            path: "Sources/VoiceIO"
        ),
        .target(
            name: "LLMClient",
            dependencies: ["CoachingEngine", "Telemetry"],
            path: "Sources/LLMClient"
        ),
        .target(
            name: "Persistence",
            dependencies: ["CoachingEngine"],
            path: "Sources/Persistence"
        ),
        .target(
            name: "HealthKitBridge",
            dependencies: ["CoachingEngine"],
            path: "Sources/HealthKitBridge"
        ),
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "Sources/DesignSystem"
        ),
        .target(
            name: "Telemetry",
            dependencies: [],
            path: "Sources/Telemetry"
        ),

        // MARK: - CLI (dev harness for the offline coaching-engine milestone)
        .executableTarget(
            name: "CoachingCLI",
            dependencies: ["CoachingEngine", "PoseVision"],
            path: "Sources/CoachingCLI"
        ),

        // MARK: - Tests
        .testTarget(
            name: "CoachingEngineTests",
            dependencies: ["CoachingEngine"],
            path: "Tests/CoachingEngineTests",
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "PoseVisionTests",
            dependencies: ["PoseVision", "CoachingEngine"],
            path: "Tests/PoseVisionTests"
        ),
        .testTarget(
            name: "VoiceIOTests",
            dependencies: ["VoiceIO", "CoachingEngine"],
            path: "Tests/VoiceIOTests"
        ),
        .testTarget(
            name: "LLMClientTests",
            dependencies: ["LLMClient", "CoachingEngine"],
            path: "Tests/LLMClientTests",
            resources: [.process("Evals")]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "CoachingEngine"],
            path: "Tests/PersistenceTests"
        ),
        .testTarget(
            name: "TelemetryTests",
            dependencies: ["Telemetry"],
            path: "Tests/TelemetryTests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "CoachingEngine",
                "PoseVision",
                "VoiceIO",
                "LLMClient",
                "Persistence",
                "Telemetry"
            ],
            path: "Tests/IntegrationTests"
        ),
        .testTarget(
            name: "DependencyDirectionTests",
            dependencies: [],
            path: "Tests/DependencyDirectionTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
