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
        return rect.integral
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

    private static func currentFrame(of window: AXUIElement) -> CGRect? {
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
        return cocoaRect(fromAX: origin, size: size)
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
    }
}
