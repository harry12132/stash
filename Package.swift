// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Stash", targets: ["Stash"])
    ],
    targets: [
        .executableTarget(
            name: "Stash",
            path: "Sources",
            resources: [
                .process("Stash_macOS26_Source/Resources")
            ]
        )
    ]
)
