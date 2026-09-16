#!/bin/zsh
# 배포용 DMG를 만든다. (다른 사람에게 전달할 설치 이미지)
#   ./scripts/make_dmg.sh              빌드 후 dist/WindowLayout-<버전>.dmg 생성
#   ./scripts/make_dmg.sh --no-build   이미 만들어진 dist/WindowLayout.app 사용
#   ./scripts/make_dmg.sh --notarize   Developer ID로 서명 + 공증 + 스테이플
#
# Gatekeeper 주의:
#   "Apple Development" 인증서는 본인 등록 기기에서만 유효하다. 그 서명으로 만든 DMG를
#   남에게 주면 "악성 코드가 없음을 확인할 수 없습니다"가 뜬다. 경고 없는 배포는
#   Developer ID Application 인증서(유료 Apple Developer Program)로 서명하고 공증해야 한다.
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARIZE=0
BUILD=1
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    --notarize) NOTARIZE=1 ;;
    *) echo "알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

APP=dist/WindowLayout.app
[[ $BUILD == 1 ]] && ./build.sh
[[ -d "$APP" ]] || { echo "❌ $APP 이 없습니다. ./build.sh 를 먼저 실행하세요."; exit 1; }

VERSION=$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleShortVersionString)
DMG="dist/WindowLayout-$VERSION.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# 배포용 인증서(Developer ID)가 있으면 그것을 쓰고, 없으면 개발용으로 떨어진다.
DEVID=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 'Developer ID Application' | sed -E 's/^[^"]*"([^"]+)".*/\1/' || true)
IDENTITY=${DEVID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 -E '^\s*[0-9]+\)' | sed -E 's/^[^"]*"([^"]+)".*/\1/' || true)}

if [[ $NOTARIZE == 1 && -z "$DEVID" ]]; then
  echo "❌ 공증하려면 'Developer ID Application' 인증서가 필요합니다(유료 Apple Developer Program)."
  echo "   현재 키체인의 서명 인증서:"
  security find-identity -v -p codesigning | sed 's/^/   /'
  exit 1
fi

# 스테이징: 앱 + /Applications 심볼릭 링크(드래그 설치) + 안내문
cp -R "$APP" "$STAGE/WindowLayout.app"
ln -s /Applications "$STAGE/Applications"

# 공증에는 hardened runtime + secure timestamp 서명이 필요하다.
if [[ -n "$DEVID" ]]; then
  codesign --force --sign "$DEVID" --identifier com.brian.windowlayout \
    --options runtime --timestamp "$STAGE/WindowLayout.app"
  echo "🔏 app signed for distribution: $DEVID"
fi

cat > "$STAGE/읽어주세요.txt" <<TXT
WindowLayout $VERSION

설치
  1. WindowLayout.app 을 옆의 Applications 폴더로 드래그합니다.
  2. 공증(notarization)된 앱이 아니라서 처음 실행이 차단될 수 있습니다.
     터미널에서 아래를 실행한 뒤 다시 여세요.

         xattr -dr com.apple.quarantine /Applications/WindowLayout.app

     또는 시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 "그래도 열기".

권한
  창을 옮기려면 손쉬운 사용 권한이 필요합니다.
  시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 에서 WindowLayout 을 켜고
  앱을 한 번 재실행하세요. 권한이 없으면 팝오버 위쪽에 노란 경고가 표시됩니다.

사용
  메뉴바의 2×2 아이콘을 누르면 팝오버가 열립니다.
  칸을 클릭하면 최전면 창이 그 자리로 이동하고,
  타일 오른쪽 위 번개 버튼은 화면의 창들을 한 번에 배치합니다.

https://github.com/beliemun/window-layout
TXT

rm -f "$DMG"
hdiutil create -volname "WindowLayout $VERSION" \
  -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

[[ -n "$IDENTITY" ]] && codesign --force --sign "$IDENTITY" --timestamp "$DMG" 2>/dev/null || true

if [[ $NOTARIZE == 1 ]]; then
  # 인증 정보는 미리 키체인 프로필로 저장해 둔다(한 번만):
  #   xcrun notarytool store-credentials windowlayout \
  #     --apple-id <Apple ID> --team-id <팀 ID> --password <앱 암호>
  PROFILE=${NOTARY_PROFILE:-windowlayout}
  echo "📤 공증 제출 중 (프로필: $PROFILE)… 몇 분 걸립니다."
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  echo "📎 stapled"
fi

echo "✅ $DMG  ($(du -h "$DMG" | cut -f1))"
if spctl -a -t open --context context:primary-signature "$DMG" >/dev/null 2>&1; then
  echo "🟢 Gatekeeper 통과 — 다른 Mac에서 경고 없이 열립니다."
else
  echo "🟡 Gatekeeper 거부 — 받는 쪽에서 아래가 필요합니다:"
  echo "     xattr -dr com.apple.quarantine <내려받은 dmg 경로>"
  echo "   경고 없이 배포하려면 Developer ID 인증서로 ./scripts/make_dmg.sh --notarize"
fi
