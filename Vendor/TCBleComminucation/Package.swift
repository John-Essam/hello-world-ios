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
    targets: [
        .target(
            name: "TCBleComminucation",
            path: "Sources/TCBleComminucation"
        )
    ]
)
