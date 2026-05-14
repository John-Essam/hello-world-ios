// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TCBleComminucation",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TCBleComminucation",
            targets: ["TCBleComminucation"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", exact: "1.8.0")
    ],
    targets: [
        .target(
            name: "TCBleComminucation",
            dependencies: [
                .product(name: "CryptoSwift", package: "CryptoSwift")
            ],
            path: "Sources/TCBleComminucation"
        )
    ]
)
