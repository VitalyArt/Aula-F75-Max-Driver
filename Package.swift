// swift-tools-version: 6.0

import PackageDescription

var dependencies: [Package.Dependency] = []

var products: [Product] = [
    .library(name: "AulaCore", targets: ["AulaCore"])
]

var targets: [Target] = [
    .target(name: "AulaCore"),
    .testTarget(name: "AulaCoreTests", dependencies: ["AulaCore"])
]

#if os(macOS)
dependencies.append(.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"))
products.append(
    .executable(name: "AulaF75MaxDriver", targets: ["AulaF75MaxDriver"])
)
targets.append(
    .executableTarget(
        name: "AulaF75MaxDriver",
        dependencies: ["AulaCore", .product(name: "Sparkle", package: "Sparkle")],
        resources: [
            .process("Resources")
        ],
        linkerSettings: [
            .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
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
targets.append(
    .testTarget(
        name: "AulaF75MaxDriverTests",
        dependencies: ["AulaF75MaxDriver"]
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
        dependencies: ["AulaCore", "AulaLinuxHID", "CAulaLinuxGTK"],
        resources: [
            .process("Resources")
        ]
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
    dependencies: dependencies,
    targets: targets
)
