// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NetSwitch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NetSwitch", targets: ["NetSwitch"])
    ],
    targets: [
        .target(
            name: "NetSwitchCore"
        ),
        .executableTarget(
            name: "NetSwitch",
            dependencies: ["NetSwitchCore"]
        ),
        .executableTarget(
            name: "NetSwitchParserTests",
            dependencies: ["NetSwitchCore"],
            path: "Tests/NetSwitchParserTests"
        )
    ]
)
