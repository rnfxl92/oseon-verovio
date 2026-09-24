// swift-tools-version: 6.0
import PackageDescription

// Verovio 조판 엔진(rism-digital/verovio, LGPLv3)을 **동적 프레임워크**로 내는 패키지.
//
// 왜 OseonKit과 따로인가: SwiftPM에서 프로덕트 종류(`.dynamic`)는 *다른 패키지*가 프로덕트로 의존할
// 때만 뜻이 있고, 같은 패키지 안의 타깃 간 의존은 프로덕트를 거치지 않는다(SE-0146). 우리 그래프
// (OseonData → VerovioBridge → VerovioCore)가 한 패키지에 있으면 VerovioCore는 앱 쪽에 정적으로도
// 들어가, 프레임워크와 두 벌이 된다. 패키지를 나누고 OseonKit이 이 패키지의 *프로덕트*에 의존해야
// 동적 링크가 실제로 일어난다(검증: 앱 실행 파일에 `vrvToolkit_*` 정의가 없어야 한다 — 2026-09-24
// 실측 0개, 프레임워크 59개).
//
// 왜 동적인가: Verovio 라이선스 페이지의 조건("not modified and dynamically linked")에 문자 그대로
// 맞추기 위해서다. LGPLv3 §4(d)(1)(a)(b)의 남은 의문(사용자가 바꿔 끼운 수정본으로 실제 실행)은
// 이것만으로 닫히지 않는다 — `docs/licensing/verovio-lgpl.md` §3·§5. 이 프레임워크에는
// 무수정 Verovio 소스(고정 태그는 Vendor/verovio/VENDORED_TAG)와 업스트림 C 래퍼만 들어가고,
// 우리 코드(VerovioBridge 등)는 앱 쪽에 남는다. 인터페이스는 Verovio 자신의 C API
// (bindings/swift-core/swift_c_wrapper.h)라서, 업스트림 소스로 다시 빌드한 호환 프레임워크로
// 바꿔 끼울 수 있다.
let package = Package(
    name: "Verovio",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "VerovioCore", type: .dynamic, targets: ["VerovioCore"]),
    ],
    targets: [
        // 소스 배치와 헤더 검색 경로는 upstream Package.swift를 따른다.
        // src/hum(humlib)은 NO_HUMDRUM_SUPPORT로 제외했다.
        .target(
            name: "VerovioCore",
            path: "Vendor/verovio",
            sources: [
                "src",
                "libmei/dist",
                "libmei/addons",
                "tools/c_wrapper.cpp",
            ],
            publicHeadersPath: "bindings/swift-core",
            cxxSettings: [
                // verovio는 잘못된 입력에 assert로 중단하는 경로가 있다(예: iomusxml.cpp
                // ReadMusicXml). 앱이 서드파티 assert로 죽지 않도록 upstream 릴리스 빌드와
                // 같이 NDEBUG로 컴파일하고, 입력 검증은 VRVToolkit(OseonKit)이 직접 한다.
                .define("NDEBUG"),
                .define("NO_HUMDRUM_SUPPORT"),
                .define("NO_DARMS_SUPPORT"),
                .define("NO_RUNTIME"),
                .headerSearchPath("include/crc"),
                .headerSearchPath("include/json"),
                .headerSearchPath("include/midi"),
                .headerSearchPath("include/pugi"),
                .headerSearchPath("include/tuning-library"),
                .headerSearchPath("include/vrv"),
                .headerSearchPath("include/zip"),
                .headerSearchPath("libmei/dist"),
                .headerSearchPath("libmei/addons"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
