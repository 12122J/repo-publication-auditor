// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "repo-publication-auditor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AuditCore",
            targets: ["AuditCore"]
        ),
        .executable(
            name: "repo-auditor",
            targets: ["RepoAuditorCLI"]
        ),
        .executable(
            name: "RepoAuditorApp",
            targets: ["RepoAuditorApp"]
        )
    ],
    targets: [
        .target(
            name: "AuditCore"
        ),
        .executableTarget(
            name: "RepoAuditorCLI",
            dependencies: ["AuditCore"]
        ),
        .executableTarget(
            name: "RepoAuditorApp",
            dependencies: ["AuditCore"]
        ),
        .testTarget(
            name: "AuditCoreTests",
            dependencies: ["AuditCore"]
        )
    ]
)
