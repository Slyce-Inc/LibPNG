// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-png",
    products: [
        .library(name: "PNG", targets: ["PNG"]),
    ],
    dependencies: [],
    targets: [
        .systemLibrary(name: "ClibPNG", path: "Library/ClibPNG", pkgConfig: "libpng", providers: [ .brew(["libpng"]), .apt(["libpng-dev"])]),
        .target(name: "PNG", dependencies: ["ClibPNG"]),
        .testTarget(name: "LibPNGTests", dependencies: ["PNG"]),
    ]
)
