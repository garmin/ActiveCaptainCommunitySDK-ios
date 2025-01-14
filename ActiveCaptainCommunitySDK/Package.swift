// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ActiveCaptainCommunitySDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ActiveCaptainCommunitySDK",
            targets: ["ActiveCaptainCommunitySDK"]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ActiveCaptainCommunitySDK",
            dependencies: [],
            path: "Sources",
            exclude: ["ActiveCaptainCommunitySDK/cpp/acdb/Thirdparty/FileUtilWindows.cpp"],
            sources: [
            // C/C++ source files
            "ActiveCaptainCommunitySDK/cpp/acdb/AcdbUrlAction.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/DataService.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/ISettingsManager.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/MarkerFactory.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/Repository.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/RwlLocker.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/SectionType.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/SettingsManager.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/SqliteCppUtil.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/StringFormatter.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/StringUtil.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/TableDataTypes.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/TextTranslator.cpp",
            "ActiveCaptainCommunitySDK/cpp/acdb/UpdateService.cpp",

            "ActiveCaptainCommunitySDK/cpp/acdb/submodules/SQLiteCpp/src",
            "ActiveCaptainCommunitySDK/cpp/acdb/submodules/SQLiteCpp/sqlite3/sqlite3.c",
            "ActiveCaptainCommunitySDK/cpp/acdb/Adapters",
            "ActiveCaptainCommunitySDK/cpp/acdb/DTO",
            "ActiveCaptainCommunitySDK/cpp/acdb/Json",
            "ActiveCaptainCommunitySDK/cpp/acdb/Navionics",
            "ActiveCaptainCommunitySDK/cpp/acdb/Presentation",
            "ActiveCaptainCommunitySDK/cpp/acdb/Queries",
            "ActiveCaptainCommunitySDK/cpp/acdb/Thirdparty",

            // Objective C/C++ source files
            "ActiveCaptainCommunitySDK/AcdbUrlAction.m",
            "ActiveCaptainCommunitySDK/ActiveCaptainDatabase.mm",
            "ActiveCaptainCommunitySDK/LastUpdateInfoType.m",
            "ActiveCaptainCommunitySDK/SearchMarker.m"
            ],
            resources: [
                .process("ActiveCaptainCommunitySDK/assets")
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                // submodule specific headers
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/submodules/mustache"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/submodules/rapidjson/include"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/submodules/SQLiteCpp/include"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/submodules/SQLiteCpp/sqlite3"),

                // ACDB specific headers
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/Include/Private"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/Include/Public"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/Thirdparty/Include/Private"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/Thirdparty/Navionics/Extensions"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/Navionics"),
                .headerSearchPath("ActiveCaptainCommunitySDK/cpp/acdb/Navionics/Stubs"),

                // SQLite specific macro definitions
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_ENABLE_RTREE"),
                .define("SQLITE_TEMP_STORE", to: "3")

            ]
            )
    ],
    cxxLanguageStandard: .cxx14
)
