// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RealmeBudsController",
    platforms: [
        .macOS(.v26)
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
