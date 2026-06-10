// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SystemWideStylizer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SystemWideStylizer",
            path: "Sources/SystemWideStylizer",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/SystemWideStylizer/Info.plist"])
            ]
        )
    ]
)
