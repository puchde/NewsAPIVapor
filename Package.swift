// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TodoApp",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.83.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.2"),
        .package(url: "https://github.com/MihaelIsaev/FCM.git", from: "2.13.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "FCM", package: "FCM")
            ]
        ),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),

            // Workaround for https://github.com/apple/swift-package-manager/issues/6940
            .product(name: "Vapor", package: "vapor"),
            .product(name: "SwiftSoup", package: "SwiftSoup"),
            .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            .product(name: "FCM", package: "FCM")
        ])
    ]
)
