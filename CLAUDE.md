# WindowLayout — 에이전트용 안내

macOS 메뉴바 창 정렬 앱(Align 대체). Swift Package + AppKit/SwiftUI, 외부 의존성 없음.

## 요구 사항
- macOS 13+, Xcode Command Line Tools 이상(`swift`, `codesign`, `iconutil`, `sips`)
- 키체인에 코드 서명 인증서가 있으면 자동 사용(없으면 ad-hoc, 아래 "권한" 참고)

## 명령
| 목적 | 명령 |
|---|---|
| 빌드+설치+실행 (기본) | `./build.sh install` → `/Applications/WindowLayout.app` |
| 빌드만 | `./build.sh` → `dist/WindowLayout.app` |
| 아이콘 재생성 | `./scripts/build_icon.sh` (build.sh가 없으면 자동 호출) |
| 권한 꼬임 초기화 | `./scripts/reset_permission.sh` |
| 팝오버 시각 검증 | `swift scripts/verify_popover.swift /tmp/pop.png` 후 이미지 확인 |

## 손쉬운 사용 권한 (가장 흔한 문제)
창 이동은 Accessibility API라 **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 허용이 필요하다.
- 권한이 없으면 팝오버 상단에 노란 경고가 뜬다. 경고가 사라져야 동작한다.
- TCC는 앱을 "번들 ID + 코드 서명 요구사항"으로 식별한다. **ad-hoc 서명은 빌드마다 신원이 바뀌어**
  설정의 토글이 켜져 있어도 새 빌드에는 적용되지 않는다. 인증서 서명이면 재빌드해도 유지된다.
- 토글이 켜져 있는데도 경고가 남으면 항목이 옛 서명에 묶인 것 → `./scripts/reset_permission.sh`로
  초기화하고 다시 허용한다. 서명 방식이 바뀐 직후에도 한 번 필요하다.
- `AXIsProcessTrusted()`는 팝오버를 열 때마다 갱신된다(`LayoutModel.refreshTarget`).

## 구조
- `Sources/WindowLayout/main.swift` — 진입점, `.accessory` 정책(독 아이콘 없음, `LSUIElement`)
- `AppDelegate.swift` — 상태바 아이템, NSPopover(`sizingOptions = []`). 팝오버 크기는 직접 지정한다.
  **탭 전환 직후 `hosting.sizeThatFits`는 이전 탭 크기를 돌려준다.** 그대로 쓰면 팝오버가 잘리거나 깜빡이므로,
  타일 영역 높이는 `PopoverView.tilesHeight(for:)`로 계산해 같은 프레임에 적용하고 나머지 높이(chrome)는
  렌더가 끝난 뒤 실측으로 보정한다.
- `LayoutModel.swift` — `LayoutCell`(0~1 비율 셀), `LayoutSpec`(셀 목록; `.grid(rows:cols:)`와 `.fullColumn(onLeft:cols:rows:)` 팩토리), `LayoutOrientation`(탭별 레이아웃·타일 비율·줄당 개수), 선택 탭(UserDefaults `orientation`, 팝오버 열 때 대상 창의 모니터 방향으로 자동 선택), 대상 앱 추적
  (`NSWorkspace.didActivateApplicationNotification`, 자기 자신 제외), 간격 설정(UserDefaults `gap`)
- `WindowMover.swift` — 자동 배치(`arrange`/`arrangeableWindows`): 창 목록과 앞뒤 순서는 `CGWindowListCopyWindowInfo`에서
  얻고(창 제목은 읽지 않으므로 화면 기록 권한이 필요 없다), 프레임이 일치하는 AX 창을 찾아 실제로 옮긴다.
  layer 0, 120×120 이상, 중심이 대상 화면 안에 있는 창만 대상이다. 포커스 창 조회, 창이 놓인 화면의 `visibleFrame`에 비율 셀을 대입(`frame(in:cell:gap:)`),
  Cocoa(좌하단 원점)↔AX(좌상단 원점, 기준은 `NSScreen.screens[0]`) 좌표 변환, 위치→크기→위치 순 적용
- `PopoverView.swift` — 팝오버 UI. 헤더(앱 + 캡슐 탭 `OrientationTabs`), 카드형 타일 `LayoutTile`, 설정 그룹(`GapStepper`, `LoginItemToggle`), 푸터(버전 + 종료). 구분선(Divider) 사용하지 않음.
  타일 안의 셀은 `.offset`으로 배치한다. **히트 영역(`contentShape`/`onHover`/`onTapGesture`)은 반드시 `.offset` 앞에**
  붙여야 한다. 뒤에 붙이면 클릭·호버가 이동 전 레이아웃 위치에서 반응한다. **LazyVGrid 금지**(표시 후 크기가 바뀌어 팝오버가 잘림)
- `Info.plist` — 번들 ID `com.brian.windowlayout`, `LSUIElement=true`, `CFBundleIconFile=AppIcon`
- `Resources/AppIcon.icns` — `scripts/make_icon.swift`가 그린 생성물

## 작업 규칙
**코드를 고쳤으면 항상 `./build.sh install`로 다시 설치한다.** 빌드만 하고 끝내지 않는다.
사용자는 `/Applications/WindowLayout.app`으로 바로 확인하므로, 설치되지 않으면 고친 것이 없는 것과 같다.
설치 후 팝오버 푸터의 버전이 방금 빌드한 값인지 확인하고, 이어서 커밋·푸시·릴리스까지 진행한다.

## 설치가 반영되지 않을 때
`pkill` 직후 바로 `open`하면 이전 프로세스가 아직 살아 있어 **새 바이너리가 실행되지 않고 기존 앱이 활성화만 된다.**
`build.sh install`은 종료를 확인한 뒤 교체·실행하고, 끝에 실제 실행 여부와 버전을 출력한다. 팝오버 푸터의 버전이
방금 빌드한 값인지 항상 확인할 것. 번들을 제자리에서 바꾸면 LaunchServices가 예전 Info.plist를 물고 있어
버전이 옛 값으로 보이므로 `lsregister -f`로 갱신한다.

## 검증 방법
1. `./build.sh install` 후 메뉴바에 2×2 아이콘이 뜨는지.
2. 스크린샷 검증 전에 **이전 캡처 파일을 지울 것.** 스크립트가 중간에 실패하면 옛 이미지가 남아
   바뀌지 않은 화면을 보고 잘못 판단하게 된다(푸터 버전으로 교차 확인).
3. `swift scripts/verify_popover.swift /tmp/pop.png` → 팝오버가 아이콘 아래에 헤더/가로·세로 탭/그리드 6개/창 간격/로그인 토글/Quit까지
   전부 보이고 권한 경고가 없는지 이미지로 확인.
4. 아무 앱 창을 띄운 뒤 셀 클릭 → 창이 해당 칸(메뉴바·독 제외 영역, 기본 간격 8px)에 맞는지.
5. 타일 우상단 번개 버튼 클릭 → 화면의 창들이 한 번에 배치되는지.
   **주의: 사용자 창을 실제로 옮긴다.** 검증용 스크립트는 배치 전 프레임을 저장했다가 끝나고 복원하도록 쓴다.
