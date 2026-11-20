// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RealmeBudsController",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RealmeBudsController",
            targets: ["RealmeBudsController"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RealmeBudsController",
            path: "Sources/RealmeBudsController",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
