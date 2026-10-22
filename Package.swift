// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchNotifyPaste",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchNotifyPaste",
            path: "Sources/NotchNotifyPaste",
            swiftSettings: [.swiftLanguageMode(.v5)]   // fewer strict-concurrency build stops in a tiny app
        )
    ]
)
