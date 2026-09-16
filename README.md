# Window Layout

Align을 대체하는 macOS 메뉴바 창 정렬 앱. 상태바 아이콘을 누르면 팝오버가 뜨고,
그리드 셀을 클릭하면 최전면 앱의 창이 화면의 해당 칸으로 이동/리사이즈된다.

## 그리드
팝오버 상단의 가로/세로 탭으로 전환한다. 팝오버를 열면 대상 창이 놓인 모니터 방향에 맞는 탭이 자동 선택된다.

| 가로 탭 (16:9 타일) | | | | |
|---|---|---|---|---|
| 1×2 (좌/우 반반) | 1×3 | 1×4 | 왼쪽 전체 높이 + 2×2 (5칸) | 왼쪽 전체 높이 + 2×3 (7칸) |
| 2×2 | 2×3 | 2×4 | 오른쪽 전체 높이 + 2×2 (5칸) | 오른쪽 전체 높이 + 2×3 (7칸) |

| 세로 탭 (9:16 타일, 한 줄) | | | | | |
|---|---|---|---|---|---|
| 2×1 (상/하 반반) | 3×1 | 4×1 | 2×2 | 3×2 | 4×2 |
| 위 전체 너비 + 2×2 (5칸) | 아래 전체 너비 + 2×2 (5칸) | 위 전체 너비 + 3×2 (7칸) | 아래 전체 너비 + 3×2 (7칸) | | |

(표는 두 줄이지만 팝오버에서는 열 개가 한 줄에 놓인다.)

가로 탭의 5칸·7칸은 한쪽 끝 열이 화면 높이 전체를 쓰고 나머지 열이 2행으로 나뉜다.
세로 탭의 5칸·7칸은 이를 90도 돌린 형태로, 한쪽 끝 행이 화면 너비 전체를 쓰고 나머지 행이 2열로 나뉜다.

## 설치 (DMG)
`WindowLayout-<버전>.dmg`를 열고 앱을 `Applications` 폴더로 드래그한다.
DMG는 `./scripts/make_dmg.sh`로 만든다(`dist/`에 생성).

### 남에게 전달할 때 (Gatekeeper)
공증(notarization)되지 않은 DMG는 다른 Mac에서 *"악성 코드가 없음을 확인할 수 없습니다"*로
차단된다. **DMG 자체가 막히므로** 받는 쪽에서 먼저 격리 속성을 벗겨야 한다:
```sh
xattr -dr com.apple.quarantine ~/Downloads/WindowLayout-1.7.0.dmg
open ~/Downloads/WindowLayout-1.7.0.dmg
# 앱을 Applications로 드래그한 뒤
xattr -dr com.apple.quarantine /Applications/WindowLayout.app
```
(GUI로만: 차단 창에서 **완료** → 시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 **그래도 열기**.
macOS 15부터는 우클릭 → 열기로는 우회되지 않는다.)

경고를 아예 없애려면 **공증**해야 한다. `Developer ID Application` 인증서가 키체인에 있으면
`make_dmg.sh`가 그것으로 hardened runtime 서명을 한다(없으면 개발용 인증서로 떨어진다).
`Apple Development`/`Apple Distribution` 인증서는 배포에 쓸 수 없다.
```sh
# 최초 1회: 공증 자격 증명을 키체인 프로필로 저장 (앱 암호는 appleid.apple.com에서 발급)
xcrun notarytool store-credentials windowlayout \
  --apple-id <Apple ID> --team-id 28Y8KR7253 --password <앱 암호>

./scripts/make_dmg.sh --notarize
```
`--notarize`는 앱을 먼저 공증·스테이플한 뒤 그 앱으로 zip과 DMG를 만들고 DMG도 공증·스테이플한다.
앱에 티켓이 박혀 있어야 DMG에서 꺼낸 뒤에도 오프라인에서 검증된다.
스크립트 끝에서 `spctl`로 두 파일의 Gatekeeper 통과 여부를 출력한다.

## 설치 (릴리스 zip)
[Releases](https://github.com/beliemun/window-layout/releases)에서 `WindowLayout.app.zip`을 받아 압축을 풀고
`/Applications`로 옮긴다. 공증(notarization)되지 않았으므로 처음 실행 시 차단되면:
```sh
xattr -dr com.apple.quarantine /Applications/WindowLayout.app
```
또는 Finder에서 우클릭 → 열기.

## 요구 사항
macOS 13+, Xcode 또는 Command Line Tools(`swift`, `codesign`, `iconutil`).

## 빌드 & 설치
```sh
./build.sh install   # 빌드 → /Applications/WindowLayout.app 설치 → 실행
./build.sh           # 빌드만 (dist/WindowLayout.app)
```
처음 실행 시 **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 WindowLayout을 허용해야 한다.
권한을 준 뒤에는 앱을 한 번 재실행한다.

### 서명과 권한
키체인에 코드 서명 인증서가 있으면 그것으로 서명해 앱 신원(identifier + 인증서)이 고정되므로
재빌드해도 손쉬운 사용 권한이 유지된다. 인증서가 없으면 임시(ad-hoc) 서명으로 떨어지는데,
이 경우 빌드마다 신원이 바뀌어 권한을 다시 켜야 한다.

토글이 켜져 있는데도 팝오버에 권한 경고가 남으면 항목이 옛 서명에 묶인 것이다:
```sh
./scripts/reset_permission.sh   # 항목 초기화 + 재실행 → 요청 창에서 허용
```

### 아이콘
`scripts/build_icon.sh`가 `scripts/make_icon.swift`로 1024px 이미지를 그려 `Resources/AppIcon.icns`를 만든다.

## 자동 배치
타일 오른쪽 위의 번개 버튼을 누르면 **현재 화면에 보이는 창들을 앞에 있는 것부터
그 레이아웃의 칸에 한 번에 채운다.** 칸보다 창이 많으면 남는 창은 건드리지 않는다.
창이 칸보다 적으면 **남는 칸을 옆 칸에 합쳐 화면을 남기지 않는다.**
예를 들어 5칸 레이아웃(왼쪽 전체 높이 + 2×2)에 창이 3개면 세 개의 전체 높이 열이 된다.
셀을 하나만 누르면 기존처럼 최전면 창 하나만 그 자리로 옮긴다.

기준 화면은 팝오버를 띄운 화면(마우스가 있는 화면)이다.

### 창끼리 딱 맞지 않는 경우
터미널이나 일부 편집기는 **문자 격자 단위로만 크기가 바뀐다.** 폭 570px를 요청해도 79칸에 해당하는 573px로
잡히는 식이다. 그대로 두면 옆 창과 겹치고 화면 밖으로 밀려나므로, 넘친 만큼 줄여 다시 요청해 칸 안에 넣는다.
그래서 이런 앱은 칸보다 몇 px 작게 배치되어 창 사이에 얇은 틈이 보일 수 있다. 겹치는 것보다 낫기 때문이다.
창이 정해진 최소 크기보다 작아지지 못하는 경우에도 칸에 딱 맞지 않는다.

## 팝오버 하단 설정
- 창 간격(px): 슬라이더 또는 −/+ 버튼
- 로그인 시 자동 실행 토글 (첫 실행 시 기본 켜짐, UserDefaults `launchAtLoginConfigured`)

## 검증
```sh
swift scripts/verify_popover.swift /tmp/pop.png   # 팝오버를 열고 화면 캡처 (터미널에 손쉬운 사용 권한 필요)
```
에이전트용 상세 안내는 `CLAUDE.md` 참고.

## 구조
- `Sources/WindowLayout/AppDelegate.swift` — 상태바 아이템, 팝오버
- `Sources/WindowLayout/LayoutModel.swift` — 대상 앱 추적, 그리드 정의, 간격 설정
- `Sources/WindowLayout/WindowMover.swift` — Accessibility API로 창 위치/크기 적용, 좌표 변환
- `Sources/WindowLayout/PopoverView.swift` — 팝오버 UI
