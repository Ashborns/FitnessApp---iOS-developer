// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "TargetRush",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "TargetRush",
            targets: ["AppModule"],
            bundleIdentifier: "com.fathi.targetrush",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
