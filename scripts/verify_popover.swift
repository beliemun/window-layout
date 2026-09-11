// 실행 중인 WindowLayout의 메뉴바 아이콘을 Accessibility로 눌러 팝오버를 연 뒤 화면을 캡처한다.
// 사용: swift scripts/verify_popover.swift [출력.png]   (실행하는 터미널에 손쉬운 사용 권한 필요)
import AppKit
import ApplicationServices

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/windowlayout-popover.png"
guard let wl = NSRunningApplication.runningApplications(withBundleIdentifier: "com.brian.windowlayout").first else {
    print("❌ WindowLayout이 실행 중이 아닙니다."); exit(1)
}
let app = AXUIElementCreateApplication(wl.processIdentifier)
var bar: CFTypeRef?
guard AXUIElementCopyAttributeValue(app, "AXExtrasMenuBar" as CFString, &bar) == .success else {
    print("❌ 메뉴바 항목에 접근 불가. 터미널에 손쉬운 사용 권한이 있는지 확인."); exit(1)
}
var kids: CFTypeRef?
AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &kids)
guard let items = kids as? [AXUIElement], let first = items.first else { print("❌ 상태바 아이콘 없음"); exit(1) }
AXUIElementPerformAction(first, kAXPressAction as CFString)
usleep(800_000)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
task.arguments = ["-x", out]
try! task.run(); task.waitUntilExit()
AXUIElementPerformAction(first, kAXPressAction as CFString) // 닫기
print("📸 \(out) — 팝오버가 아이콘 아래에 전부 보이는지, 권한 경고가 없는지 확인")
