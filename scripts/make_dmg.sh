#!/bin/zsh
# 배포용 DMG를 만든다. (다른 사람에게 전달할 설치 이미지)
#   ./scripts/make_dmg.sh        빌드 후 dist/WindowLayout-<버전>.dmg 생성
#   ./scripts/make_dmg.sh --no-build   이미 만들어진 dist/WindowLayout.app 사용
set -euo pipefail
cd "$(dirname "$0")/.."

APP=dist/WindowLayout.app
if [[ "${1:-}" != "--no-build" ]]; then
  ./build.sh
fi
[[ -d "$APP" ]] || { echo "❌ $APP 이 없습니다. ./build.sh 를 먼저 실행하세요."; exit 1; }

VERSION=$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleShortVersionString)
DMG="dist/WindowLayout-$VERSION.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# 스테이징: 앱 + /Applications 심볼릭 링크(드래그 설치) + 안내문
cp -R "$APP" "$STAGE/WindowLayout.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/읽어주세요.txt" <<TXT
WindowLayout $VERSION

설치
  1. WindowLayout.app 을 옆의 Applications 폴더로 드래그합니다.
  2. 공증(notarization)된 앱이 아니라서 처음 실행이 차단될 수 있습니다.
     터미널에서 아래를 실행한 뒤 다시 여세요.

         xattr -dr com.apple.quarantine /Applications/WindowLayout.app

     (또는 Finder에서 앱을 우클릭 → 열기 → 열기)

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

# DMG도 앱과 같은 신원으로 서명한다(인증서가 있을 때만).
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -E '^\s*[0-9]+\)' | sed -E 's/^[^"]*"([^"]+)".*/\1/')
[[ -n "$IDENTITY" ]] && codesign --force --sign "$IDENTITY" "$DMG" 2>/dev/null || true

echo "✅ $DMG  ($(du -h "$DMG" | cut -f1))"
