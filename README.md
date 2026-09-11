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

5칸·7칸 레이아웃은 한쪽 끝 열이 화면 높이 전체를 쓰고, 나머지 열이 2행으로 나뉜다.

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
