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
  # 이전 프로세스가 살아 있으면 open이 새 바이너리를 띄우지 않고 그대로 활성화만 한다.
  # 반드시 종료를 확인한 뒤에 교체·실행한다.
  pkill -x WindowLayout 2>/dev/null || true
  for _ in {1..40}; do
    pgrep -x WindowLayout >/dev/null || break
    sleep 0.1
  done
  if pgrep -x WindowLayout >/dev/null; then
    pkill -9 -x WindowLayout 2>/dev/null || true
    sleep 0.5
  fi

  rm -rf /Applications/WindowLayout.app
  cp -R "$APP" /Applications/WindowLayout.app
  # 번들을 제자리에서 바꾸면 LaunchServices가 예전 Info.plist를 물고 있어 버전이 옛 값으로 보인다.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f /Applications/WindowLayout.app >/dev/null 2>&1 || true
  open /Applications/WindowLayout.app

  for _ in {1..40}; do
    pgrep -x WindowLayout >/dev/null && break
    sleep 0.1
  done
  if pgrep -x WindowLayout >/dev/null; then
    echo "🚀 installed & launched: /Applications/WindowLayout.app (v$(defaults read /Applications/WindowLayout.app/Contents/Info.plist CFBundleShortVersionString))"
  else
    echo "⚠️  설치는 했지만 실행되지 않았습니다: /Applications/WindowLayout.app"
    exit 1
  fi
fi
