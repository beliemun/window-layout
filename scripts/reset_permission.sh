#!/bin/zsh
# 손쉬운 사용 권한 항목이 옛 서명에 묶여 토글이 먹지 않을 때 초기화하고 앱을 재실행한다.
# 실행 후 뜨는 권한 요청 창에서 허용 → 시스템 설정 → 손쉬운 사용에서 WindowLayout 켜기.
set -euo pipefail
tccutil reset Accessibility com.brian.windowlayout
pkill -x WindowLayout 2>/dev/null || true
sleep 1
open /Applications/WindowLayout.app
echo "🔁 권한 초기화 및 재실행 완료. 권한 요청 창에서 허용하세요."
