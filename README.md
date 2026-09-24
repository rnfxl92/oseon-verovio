# Oseon — Verovio corresponding source

Oseon is a sheet-music app for iPad and iPhone. It engraves scores with
[Verovio](https://www.verovio.org), which is licensed under the **GNU Lesser General Public License v3**
(`Verovio/Vendor/verovio/COPYING.LESSER`, with `COPYING` for the GPL v3 it incorporates).

Oseon ships Verovio as a **separate dynamic framework**, `Oseon.app/Frameworks/VerovioCore.framework`. Oseon's own
code lives in the app executable and talks to the framework only through Verovio's C API
(`Verovio/Vendor/verovio/bindings/swift-core/swift_c_wrapper.h`, which declares the functions implemented in
`Verovio/Vendor/verovio/tools/c_wrapper.cpp`).

This repository is the complete corresponding source of that framework, published so that anyone can rebuild it,
modify it, and (subject to Apple's platform rules, see below) run Oseon with the modified version — as
LGPL v3 §4(d) and GPL v3 §6(d) require. Nothing here is Oseon's application code.

## Which Oseon build does this match?

Each Oseon release is tagged here as `oseon-<version>-<build>` and points at the exact Verovio sources and build
definition that produced the framework shipped in that release.

| Oseon | Git tag here | Verovio |
|---|---|---|
| 1.0 (1), published 2026-09-24 | `oseon-1.0-1` | `version-6.2.1` |

## What is in here

- `Verovio/Vendor/verovio/` — a subset of the upstream Verovio tree at the tag above, **unmodified**: every file
  here is byte-identical to upstream (verified with `diff -r` against the tag). The subset leaves out what the
  build does not use: `src/hum`, `include/hum`, `include/win32`, and the bindings, tools, fonts and docs that are not
  listed in `scripts/vendor-verovio.sh`. `VENDORED_TAG` records the upstream tag.
- `Verovio/Package.swift` — the Swift Package manifest that defines the framework: the list of compiled sources,
  header search paths, the C++ standard (C++20) and the four preprocessor definitions the build sets:
  `NDEBUG`, `NO_HUMDRUM_SUPPORT`, `NO_DARMS_SUPPORT`, `NO_RUNTIME`. No Verovio source file is patched; these
  flags only select upstream code paths.
- `Verovio/.swiftpm/xcode/xcshareddata/xcschemes/VerovioCore.xcscheme` — a shared Xcode scheme so the framework
  can be built from the command line without opening Xcode.
- `scripts/vendor-verovio.sh` — the script that produces the subset from upstream (it also copies the SMuFL fonts
  Oseon bundles as app resources; those fonts are not part of the framework and are not in this repository).
- `THIRD-PARTY-NOTICES.md` — the notices for the third-party code compiled into Verovio (pugixml, midifile,
  jsonxx, miniz-cpp, crc, tuning-library, a Base64 routine) as Oseon displays them in its "Open-source licenses"
  screen, plus the fonts' notices.

## Rebuilding the framework

Requirements: macOS with Xcode 27 or later (Swift tools 6.0, iOS 17 SDK). No other dependencies.

```sh
git clone https://github.com/rnfxl92/oseon-verovio.git
cd oseon-verovio
git checkout oseon-1.0-1     # or the tag matching your Oseon build
cd Verovio
xcodebuild build -scheme VerovioCore -destination 'generic/platform=iOS' -configuration Release \
  CODE_SIGNING_ALLOWED=NO -derivedDataPath build
```

The framework is written to `build/Build/Products/Release-iphoneos/PackageFrameworks/VerovioCore.framework`.
To build for the simulator, use `-destination 'generic/platform=iOS Simulator'`; the output is then under
`Release-iphonesimulator/PackageFrameworks/`.

Any build that keeps the C API in `swift_c_wrapper.h` interface-compatible works with Oseon; the app never
references Verovio's C++ symbols.

## Running Oseon with your modified framework

iOS only runs code that is signed, and every framework inside an app must be signed with the same identity as the
app. So to use a modified `VerovioCore.framework` you must re-sign the whole app with your own Apple Developer
signing identity and a provisioning profile that includes your device:

1. Obtain the Oseon `.ipa` for the build you are matching (for example with Apple Configurator on a Mac).
2. Unzip it, replace `Payload/Oseon.app/Frameworks/VerovioCore.framework` with your build, and re-sign the
   framework and then the app with `codesign --force --sign "<your identity>"` (the app additionally needs
   `--entitlements` with your own entitlements and an embedded provisioning profile that covers your device).
3. Zip `Payload` back into an `.ipa` and install it with Xcode's Devices window or
   `xcrun devicectl device install app`.

This re-signing step is a restriction of Apple's platform, not of Oseon: the app itself does nothing to prevent
the replacement. Verovio's maintainers have stated that, for App Store apps, crediting Verovio in the store metadata
and publishing any modifications to Verovio are what they require
([rism-digital/verovio#2559](https://github.com/rism-digital/verovio/issues/2559)).

## Licenses

- Verovio and its bundled third-party code: as stated in their own files (`COPYING.LESSER`, `COPYING`,
  `THIRD-PARTY-NOTICES.md`). Verovio is Copyright (c) Authors and others; see https://www.verovio.org.
- The files that are Oseon's own contribution to this repository — `Verovio/Package.swift`, the shared scheme,
  `scripts/vendor-verovio.sh`, the publishing script and this README — are released under the
  [MIT License](LICENSE) so that anyone can reuse the build recipe.

Questions about this repository: open an issue here.
