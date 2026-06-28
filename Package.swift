// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AulaF75MaxDriver",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AulaF75MaxDriver", targets: ["AulaF75MaxDriver"])
    ],
    targets: [
        .executableTarget(
            name: "AulaF75MaxDriver",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
