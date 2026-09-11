import AppKit
import ApplicationServices

enum AccessibilityAccess {
    @discardableResult
    static func requestIfNeeded() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

enum WindowMover {
    static func move(appPID: pid_t, cell: LayoutCell, gap: CGFloat) {
        let appElement = AXUIElementCreateApplication(appPID)
        guard let window = focusedWindow(of: appElement) else { NSSound.beep(); return }
        let screen = screen(for: window)
        let target = frame(in: screen.visibleFrame, cell: cell, gap: gap)
        setFrame(of: window, cocoaRect: target)
    }

    /// 앱의 포커스 창이 세로 모니터에 있으면 true. 창을 못 찾으면 nil.
    static func isFocusedWindowOnPortraitScreen(appPID: pid_t) -> Bool? {
        guard let window = focusedWindow(of: AXUIElementCreateApplication(appPID)) else { return nil }
        let frame = screen(for: window).frame
        return frame.height > frame.width
    }

    // MARK: - Geometry

    /// 비율 셀(원점 좌상단)을 화면 영역(visibleFrame, Cocoa 좌표계)의 실제 프레임으로 변환한다.
    /// 바깥 여백과 창 사이 여백이 모두 gap이 되도록 영역과 셀을 각각 gap/2씩 줄인다.
    static func frame(in area: CGRect, cell: LayoutCell, gap: CGFloat) -> CGRect {
        let a = area.insetBy(dx: gap / 2, dy: gap / 2)
        let rect = CGRect(
            x: a.minX + a.width * cell.x,
            y: a.maxY - a.height * (cell.y + cell.h),
            width: a.width * cell.w,
            height: a.height * cell.h
        ).insetBy(dx: gap / 2, dy: gap / 2)

        // 각 변을 반올림한다. CGRect.integral은 바깥으로 올림해서 칸이 1~2px씩 커지고
        // 이웃한 창끼리 겹친다(예: 4열이면 한 칸 폭이 427.5px).
        // 맞닿은 변은 같은 값으로 반올림되므로 겹치지도, 틈이 생기지도 않는다.
        let left = rect.minX.rounded()
        let bottom = rect.minY.rounded()
        let right = rect.maxX.rounded()
        let top = rect.maxY.rounded()
        return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }

    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    /// AX(좌상단 원점) → Cocoa(좌하단 원점)
    private static func cocoaRect(fromAX origin: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: origin.x, y: primaryHeight - origin.y - size.height, width: size.width, height: size.height)
    }

    /// Cocoa → AX
    private static func axOrigin(fromCocoa rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX, y: primaryHeight - rect.maxY)
    }

    // MARK: - Accessibility

    private static func focusedWindow(of app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() {
            return (v as! AXUIElement)
        }
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
           let list = value as? [AXUIElement], let first = list.first {
            return first
        }
        return nil
    }

    /// 창의 프레임을 AX 좌표계(좌상단 원점) 그대로 돌려준다. CGWindowList의 bounds와 같은 좌표계다.
    static func axFrame(of window: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let p = posValue, let s = sizeValue
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin),
              AXValueGetValue(s as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func currentFrame(of window: AXUIElement) -> CGRect? {
        guard let ax = axFrame(of: window) else { return nil }
        return cocoaRect(fromAX: ax.origin, size: ax.size)
    }

    /// 창의 중심이 놓인 화면. 못 찾으면 마우스가 있는 화면, 그것도 없으면 메인 화면.
    private static func screen(for window: AXUIElement) -> NSScreen {
        if let frame = currentFrame(of: window) {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            if let s = NSScreen.screens.first(where: { $0.frame.contains(center) }) { return s }
        }
        let mouse = NSEvent.mouseLocation
        if let s = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) { return s }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - 자동 배치

    /// 마우스가 있는 화면(= 팝오버를 띄운 화면). 없으면 메인 화면.
    static func currentScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// 해당 화면에 보이는 창을 앞에 있는 것부터(z-order) 돌려준다.
    /// 창 목록과 순서는 CGWindowList에서 얻고(제목은 읽지 않으므로 화면 기록 권한이 필요 없다),
    /// 실제 이동은 프레임이 일치하는 AX 창으로 한다.
    static func arrangeableWindows(on screen: NSScreen) -> [AXUIElement] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }

        // 화면 영역을 AX 좌표계로
        let screenArea = CGRect(
            x: screen.frame.minX,
            y: primaryHeight - screen.frame.maxY,
            width: screen.frame.width,
            height: screen.frame.height
        )

        var axWindowsByPID: [pid_t: [AXUIElement]] = [:]
        var result: [AXUIElement] = []

        for entry in info {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"],
                  width >= 120, height >= 120   // 팔레트·툴팁 같은 작은 창 제외
            else { continue }

            let frame = CGRect(x: x, y: y, width: width, height: height)
            guard screenArea.contains(CGPoint(x: frame.midX, y: frame.midY)) else { continue }

            let windows: [AXUIElement]
            if let cached = axWindowsByPID[pid] {
                windows = cached
            } else {
                var value: CFTypeRef?
                AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value)
                windows = (value as? [AXUIElement]) ?? []
                axWindowsByPID[pid] = windows
            }

            guard let match = windows.first(where: { window in
                guard let f = axFrame(of: window) else { return false }
                return abs(f.minX - frame.minX) < 2 && abs(f.minY - frame.minY) < 2
                    && abs(f.width - frame.width) < 2 && abs(f.height - frame.height) < 2
            }) else { continue }
            guard !result.contains(where: { CFEqual($0, match) }) else { continue }

            result.append(match)
        }
        return result
    }

    /// 화면에 보이는 창들을 레이아웃의 칸에 앞에서부터 채운다. 배치한 창 수를 돌려준다.
    /// 칸보다 창이 많으면 남는 창은 건드리지 않는다.
    @discardableResult
    static func arrange(cells: [LayoutCell], gap: CGFloat, on screen: NSScreen) -> Int {
        let windows = arrangeableWindows(on: screen)
        let count = min(windows.count, cells.count)
        guard count > 0 else { return 0 }
        for index in 0..<count {
            setFrame(of: windows[index], cocoaRect: frame(in: screen.visibleFrame, cell: cells[index], gap: gap))
        }
        return count
    }

    private static func setFrame(of window: AXUIElement, cocoaRect rect: CGRect) {
        var origin = axOrigin(fromCocoa: rect)
        var size = CGSize(width: rect.width, height: rect.height)
        guard let posValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }
        // 최소/최대 크기 제약이 있는 창을 위해 위치 → 크기 → 위치 순으로 두 번 적용
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)

        // 크기 변경을 늦게 반영하는 앱이 있어 한 번 더 확인하고 맞춘다.
        // (창 자체의 최소 크기 때문에 못 맞추는 경우는 그대로 둔다)
        if let current = axFrame(of: window),
           abs(current.width - rect.width) > 1 || abs(current.height - rect.height) > 1 {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
    }
}
