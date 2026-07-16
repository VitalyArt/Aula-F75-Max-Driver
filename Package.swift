// swift-tools-version: 6.0

import PackageDescription

var products: [Product] = [
    .library(name: "AulaCore", targets: ["AulaCore"])
]

var targets: [Target] = [
    .target(name: "AulaCore")
]

#if os(macOS)
products.append(
    .executable(name: "AulaF75MaxDriver", targets: ["AulaF75MaxDriver"])
)
targets.append(
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
)
#endif

#if os(Linux)
products.append(
    .executable(name: "AulaF75MaxDriverLinux", targets: ["AulaLinuxApp"])
)
targets.append(contentsOf: [
    .systemLibrary(
        name: "CHIDAPI",
        pkgConfig: "hidapi-hidraw",
        providers: [
            .apt(["libhidapi-dev"]),
            .yum(["hidapi-devel"])
        ]
    ),
    .systemLibrary(
        name: "CGTK4",
        pkgConfig: "gtk4",
        providers: [
            .apt(["libgtk-4-dev"]),
            .yum(["gtk4-devel"])
        ]
    ),
    .target(
        name: "CAulaLinuxGTK",
        dependencies: ["CGTK4"],
        publicHeadersPath: "include"
    ),
    .target(
        name: "AulaLinuxHID",
        dependencies: ["AulaCore", "CHIDAPI"]
    ),
    .executableTarget(
        name: "AulaLinuxApp",
        dependencies: ["AulaCore", "AulaLinuxHID", "CAulaLinuxGTK"]
    )
])
#endif

let package = Package(
    name: "AulaF75MaxDriver",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    targets: targets
)
