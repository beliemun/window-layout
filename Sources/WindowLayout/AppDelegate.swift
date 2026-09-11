import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model = LayoutModel()
    private var hosting: NSHostingController<PopoverView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityAccess.requestIfNeeded()

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
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }
        model.refreshTarget()
        popover.contentSize = hosting.sizeThatFits(in: NSSize(width: PopoverView.width, height: 10_000))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
