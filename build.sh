#!/bin/zsh
# 릴리스 빌드 후 dist/WindowLayout.app 번들을 만든다.
#   ./build.sh          빌드만
#   ./build.sh install  빌드 후 /Applications에 설치하고 실행
set -euo pipefail
cd "$(dirname "$0")"

# 아이콘이 없으면 생성
[[ -f Resources/AppIcon.icns ]] || ./scripts/build_icon.sh

swift build -c release

APP=dist/WindowLayout.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/WindowLayout "$APP/Contents/MacOS/WindowLayout"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# 서명: 키체인에 코드 서명 인증서가 있으면 그것으로 서명해 신원을 고정한다.
# (임시 ad-hoc 서명은 빌드마다 신원이 바뀌어 손쉬운 사용 권한이 초기화된다.)
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -E '^\s*[0-9]+\)' | sed -E 's/^[^"]*"([^"]+)".*/\1/')
if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" --identifier com.brian.windowlayout "$APP" 2>/dev/null
  echo "🔏 signed with: $IDENTITY"
else
  codesign --force --sign - "$APP" >/dev/null
  echo "🔏 ad-hoc signed (권한이 빌드마다 초기화됨)"
fi
echo "✅ built: $APP"

if [[ "${1:-}" == "install" ]]; then
  pkill -x WindowLayout 2>/dev/null || true
  sleep 0.5
  rm -rf /Applications/WindowLayout.app
  cp -R "$APP" /Applications/WindowLayout.app
  open /Applications/WindowLayout.app
  echo "🚀 installed & launched: /Applications/WindowLayout.app"
fi
