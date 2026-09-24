#!/bin/bash
# Verovio(악보 조판 엔진) 소스를 저장소 안으로 벤더링한다(엔진은 Verovio/ 패키지, 폰트는 OseonKit).
#
# SwiftPM 타깃은 패키지 루트 밖의 경로를 참조할 수 없고 리소스는 소유 타깃
# 디렉터리 안에 있어야 하므로, 산출물이 두 곳으로 나뉜다.
#   - Verovio/Vendor/verovio            : C++ 소스/헤더 (VerovioCore 타깃)
#   - OseonKit/Sources/VerovioBridge/... : 런타임 폰트 데이터 (VerovioBridge 리소스)
#
# 사용법: scripts/vendor-verovio.sh [version-태그]  (생략 시 최신 version-* 태그)
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-}"
if [ -z "$TAG" ]; then
  TAG="$(git ls-remote --tags https://github.com/rism-digital/verovio.git 'version-*' \
    | awk -F/ '{print $NF}' | grep -v '\^{}' | sort -V | tail -1)"
fi
echo "vendoring verovio $TAG"

CORE="Verovio/Vendor/verovio"
DATA="OseonKit/Sources/VerovioBridge/Resources/verovio"
TMP=".verovio-vendor-tmp"

rm -rf "$CORE" "$DATA" "$TMP"
git clone --quiet --depth 1 --branch "$TAG" https://github.com/rism-digital/verovio.git "$TMP"

mkdir -p "$CORE/libmei" "$CORE/bindings" "$CORE/tools" "$DATA"

# C++ 소스. src/hum(humlib, 3.4MB 단일 파일)은 NO_HUMDRUM_SUPPORT로 제외한다.
cp -R "$TMP/src" "$CORE/"
rm -rf "$CORE/src/hum"
cp -R "$TMP/include" "$CORE/"
rm -rf "$CORE/include/hum" "$CORE/include/win32"
cp -R "$TMP/libmei/dist" "$TMP/libmei/addons" "$CORE/libmei/"
# C 바인딩 — ObjC++ 브리지가 C++ Toolkit 대신 이 안정 API를 쓴다.
cp -R "$TMP/bindings/swift-core" "$CORE/bindings/"
cp "$TMP/tools/c_wrapper.h" "$TMP/tools/c_wrapper.cpp" "$CORE/tools/"
cp "$TMP/COPYING" "$TMP/COPYING.LESSER" "$CORE/"
echo "$TAG" > "$CORE/VENDORED_TAG"

# 런타임 데이터. Resources::InitFonts()가 Bravura(폴백)와 Leipzig(기본)를 항상
# 로드하므로 두 폰트와 text/ 폰트만 남기고 나머지 SMuFL 폰트는 제외한다.
for f in Bravura Bravura.xml Bravura.css \
         Leipzig Leipzig.xml Leipzig.css \
         text Liberation.css footer.svg tuning-glyphnames.json; do
  cp -R "$TMP/data/$f" "$DATA/"
done

# 폰트 라이선스(SIL OFL 1.1) — verovio 태그에는 폰트별 라이선스 파일이 없어 업스트림 원문을 가져온다.
# URL은 브랜치가 아니라 **커밋에 핀한다**: 브랜치를 가리키면 다시 돌릴 때마다 다른 원문이 내려와
# 동봉본과 조용히 어긋날 수 있고, 무엇을 동봉했는지도 기록에 남지 않는다. 라이선스가 갱신되면
# 아래 SHA를 의도적으로 올리고 FONT-LICENSES.md의 짧은 SHA도 함께 고친다.
# 고지 없이 출시할 수 없으므로 실패는 경고가 아니라 중단이다.
BRAVURA_COMMIT="632e925353aab2ac0a81c97a4662d315a82b56f4"
LEIPZIG_COMMIT="a8838c6fe6bf3aaf4bfb5d831436b4f7594dbf9c"
BRAVURA_LICENSE="https://raw.githubusercontent.com/steinbergmedia/bravura/$BRAVURA_COMMIT/LICENSE.txt"
LEIPZIG_LICENSE="https://raw.githubusercontent.com/rism-digital/leipzig/$LEIPZIG_COMMIT/LICENSE.txt"
curl -fsSL "$BRAVURA_LICENSE" -o "$DATA/Bravura-LICENSE.txt" || { echo "Bravura license fetch failed" >&2; exit 1; }
curl -fsSL "$LEIPZIG_LICENSE" -o "$DATA/Leipzig-LICENSE.txt" || { echo "Leipzig license fetch failed" >&2; exit 1; }
grep -q "SIL OPEN FONT LICENSE" "$DATA/Bravura-LICENSE.txt" && grep -q "SIL OPEN FONT LICENSE" "$DATA/Leipzig-LICENSE.txt" \
  || { echo "font license text is not OFL" >&2; exit 1; }
cat > "$DATA/FONT-LICENSES.md" <<'EOF'
# Bundled fonts

- **Bravura** — © Steinberg Media Technologies GmbH, designed by Daniel Spreadbury. SIL Open Font License 1.1 — see `Bravura-LICENSE.txt`.
- **Leipzig** — © Verovio contributors (RISM Digital). SIL Open Font License 1.1 — see `Leipzig-LICENSE.txt`.
- **Liberation** — © 2012 Red Hat, Inc.; digitized data © 2010 Google Corporation. SIL Open Font License 1.1 — see `Liberation-LICENSE.txt` (embedded as woff2 in `Liberation.css`).

The font files are vendored from Verovio at the pinned tag in `Verovio/Vendor/verovio/VENDORED_TAG`. That tag ships no per-font license file, so the three license texts here are fetched from the font projects' own repositories at pinned commits: `Bravura-LICENSE.txt` from `steinbergmedia/bravura` @ `632e925`, `Leipzig-LICENSE.txt` from `rism-digital/leipzig` @ `a8838c6`, `Liberation-LICENSE.txt` from `liberationfonts/liberation-fonts` @ `49e1358`. `scripts/vendor-verovio.sh` regenerates this file and all three license texts.
EOF

# ---------------------------------------------------------------------------------------------
# 오픈소스 고지 — LGPLv3 §4(a)(b)(c): 앱에 LGPL·GPL 원문을 동봉하고, 엔진 안 제3자 코드와 폰트의 저작권 고지를
# 보인다(`docs/licensing/verovio-lgpl.md`). `OpenSourceNotices`(OseonData)가 아래 파일 이름을 그대로 보고,
# `OpenSourceNoticesTests`가 번들에 있는지·기대한 원문인지 지킨다. 고지 없이 출시할 수 없으므로 실패는 중단이다.
# ---------------------------------------------------------------------------------------------
cp "$TMP/COPYING" "$TMP/COPYING.LESSER" "$DATA/"

# Liberation(텍스트 폰트, Liberation.css에 woff2로 내장)과 midifile(벤더 트리에 LICENSE가 없다)의 원문 — 커밋에 핀한다.
LIBERATION_COMMIT="49e1358e4017577429c9f8c39a3e6e879093264e"
MIDIFILE_COMMIT="98917df5b1bf0d6e8d4c0e5fff86d6b05343e793"
curl -fsSL "https://raw.githubusercontent.com/liberationfonts/liberation-fonts/$LIBERATION_COMMIT/LICENSE" \
  -o "$TMP/Liberation-LICENSE.txt" || { echo "Liberation license fetch failed" >&2; exit 1; }
grep -q "SIL OPEN FONT LICENSE" "$TMP/Liberation-LICENSE.txt" || { echo "Liberation license text is not OFL" >&2; exit 1; }
cp "$TMP/Liberation-LICENSE.txt" "$DATA/"
curl -fsSL "https://raw.githubusercontent.com/craigsapp/midifile/$MIDIFILE_COMMIT/LICENSE.txt" \
  -o "$TMP/midifile-LICENSE.txt" || { echo "midifile license fetch failed" >&2; exit 1; }
grep -q "Craig Stuart Sapp" "$TMP/midifile-LICENSE.txt" || { echo "midifile license text unexpected" >&2; exit 1; }

# 헤더에서 고지 블록을 뽑는다 — 마커가 안 잡히면(버전이 바뀌어 문구가 달라짐) 조용히 빈 고지를 내지 않고 중단한다.
# 마커는 **리터럴 부분 문자열**이다(정규식이 아니다) — `awk -v`가 백슬래시 이스케이프를 먹어 `\(C\)`가 그룹 `(C)`로
# 바뀌는 함정이 있었다. `index()`는 그런 해석을 하지 않는다.
extract() {   # extract <file> <start-substring> <end-substring>
  local out
  out="$(awk -v s="$2" -v e="$3" 'f==0 && index($0, s) {f=1} f {print} f && index($0, e) {exit}' "$1")"
  [ -n "$out" ] || { echo "notice marker not found: $2 in $1" >&2; exit 1; }
  # 끝 마커도 확인한다 — 없으면 awk가 파일 끝까지 뱉는데 출력이 비지 않아 조용히 통과한다.
  case "$out" in *"$3"*) ;; *) echo "notice end marker not found: $3 in $1" >&2; exit 1 ;; esac
  printf '%s\n' "$out"
}
{
  echo "# Third-party notices bundled with Oseon"
  echo
  echo "Oseon engraves scores with Verovio $TAG (GNU LGPL v3 — see COPYING.LESSER and COPYING in this directory)."
  echo "Verovio: Copyright (c) Authors and others. All rights reserved. https://www.verovio.org"
  echo "The Verovio build embeds the following third-party code; their notices are reproduced below."
  echo "Fonts: Bravura (Bravura-LICENSE.txt), Leipzig (Leipzig-LICENSE.txt), Liberation (Liberation-LICENSE.txt) — SIL Open Font License 1.1."
  echo
  # `(c)`는 파일 **끝**의 라이선스 블록, `(C)`는 맨 위 헤더 주석이다 — 리터럴 매칭이라 대소문자로 갈린다.
  echo "## pugixml (MIT)"; echo; extract "$CORE/include/pugi/pugiconfig.hpp" 'Copyright (c) 2006-' 'OTHER DEALINGS IN THE SOFTWARE'; echo
  echo "## midifile (BSD-2-Clause) — https://github.com/craigsapp/midifile @ ${MIDIFILE_COMMIT:0:7}"; echo; cat "$TMP/midifile-LICENSE.txt"; echo
  echo "## jsonxx (MIT)"; echo; cat "$CORE/include/json/LICENSE"; echo
  echo "## miniz-cpp (MIT) and miniz (MIT / public domain)"; echo
  extract "$CORE/include/zip/zip_file.hpp" 'Copyright (c) 2014-2017 Thomas Fussell' '@license: http://www.opensource.org/licenses/mit-license.php'; echo
  # 끝 마커를 허가문 끝으로 둔다 — 저작권 줄에서 끊으면 MIT 허가 전문이 통째로 빠진다.
  extract "$CORE/include/zip/zip_file.hpp" 'Copyright 2013-2014 RAD Game Tools and Valve Software' 'OTHER DEALINGS IN'; echo
  # 같은 허가문이 붙은 ZIP 읽기 블록에는 저작권자가 하나 더 있다 — 표기만 따로 뽑는다(허가문은 위와 같다).
  extract "$CORE/include/zip/zip_file.hpp" 'Copyright 2016 Martin Raiber' 'All Rights Reserved.'; echo
  extract "$CORE/include/zip/zip_file.hpp" 'This is free and unencumbered software released into the public domain' 'OTHER DEALINGS IN THE SOFTWARE'; echo
  echo "## crc (public domain)"; echo; extract "$CORE/include/crc/crc.h" 'Copyright (c) 2000 by Michael Barr' 'expressed or implied'; echo
  echo "## tuning-library (MIT)"; echo; cat "$CORE/include/tuning-library/LICENSE.md"; echo
  echo "## Base64 (in src/vrv.cpp)"; echo; extract "$CORE/src/vrv.cpp" 'base64.cpp and base64.h' 'rene.nyffenegger@adp-gmbh.ch'; echo
} > "$DATA/THIRD-PARTY-NOTICES.md"
for marker in "Arseny Kapoulkine" "Craig Stuart Sapp" "Hong Jiang" "Thomas Fussell" "Rich Geldreich" "Martin Raiber" "Michael Barr" "Paul Walker" "Nyffenegger"; do
  grep -q "$marker" "$DATA/THIRD-PARTY-NOTICES.md" || { echo "third-party notice missing: $marker" >&2; exit 1; }
done

rm -rf "$TMP"
echo "vendored: $CORE ($(du -sh "$CORE" | cut -f1)), $DATA ($(du -sh "$DATA" | cut -f1))"
