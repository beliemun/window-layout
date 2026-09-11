import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model = LayoutModel()
    private var hosting: NSHostingController<PopoverView>!
    /// 타일 영역을 뺀 나머지 높이(헤더 + 설정 + 푸터). 실제 렌더 결과로 보정한다.
    private var chromeHeight: CGFloat?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityAccess.requestIfNeeded()
        enableLaunchAtLoginByDefault()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "Window Layout")
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.animates = false
        hosting = NSHostingController(rootView: PopoverView(model: model))
        // SwiftUI가 크기를 자동 갱신하며 팝오버를 재배치하지 않도록 끄고, 표시 직전에 직접 크기를 정한다.
        hosting.sizingOptions = []
        popover.contentViewController = hosting

        model.onApplied = { [weak self] in self?.popover.performClose(nil) }
        // 탭 전환과 동시에(같은 프레임에) 크기를 맞춰야 깜빡이지 않는다.
        model.onLayoutChanged = { [weak self] in self?.updatePopoverSize() }
    }

    /// 탭을 바꾼 직후에는 SwiftUI가 아직 새 상태로 레이아웃되지 않아 측정값이 이전 탭 크기로 나온다.
    /// 그래서 타일 높이는 직접 계산해 즉시 적용하고(깜빡임·잘림 방지), 렌더가 끝난 뒤 실측으로 보정한다.
    private func updatePopoverSize() {
        let tiles = PopoverView.tilesHeight(for: model.orientation)
        if let chrome = chromeHeight {
            setContentSize(NSSize(width: PopoverView.width, height: chrome + tiles))
        } else {
            let measured = hosting.sizeThatFits(in: NSSize(width: PopoverView.width, height: 10_000))
            if measured.height > 0 { setContentSize(measured) }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let measured = self.hosting.sizeThatFits(in: NSSize(width: PopoverView.width, height: 10_000))
            guard measured.height > 0 else { return }
            self.chromeHeight = measured.height - PopoverView.tilesHeight(for: self.model.orientation)
            self.setContentSize(measured)
        }
    }

    private func setContentSize(_ size: NSSize) {
        guard size.width > 0, size.height > 0, size != popover.contentSize else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        popover.contentSize = size
        CATransaction.commit()
    }

    /// 첫 실행 시 로그인 항목을 기본으로 등록한다. 이후에는 사용자가 팝오버에서 바꾼 값을 존중한다.
    private func enableLaunchAtLoginByDefault() {
        let key = "launchAtLoginConfigured"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            NSLog("launch at login register failed: \(error.localizedDescription)")
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }
        model.refreshTarget()
        updatePopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
