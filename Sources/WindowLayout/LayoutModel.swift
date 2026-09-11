import AppKit
import Combine

struct GridSpec: Hashable, Identifiable {
    let rows: Int
    let cols: Int
    var id: String { "\(rows)x\(cols)" }
}

final class LayoutModel: ObservableObject {
    /// 팝오버에 표시할 그리드. 윗줄은 1행(1×2, 1×3, 1×4), 아랫줄은 2행(2×2, 2×3, 2×4).
    static let grids: [GridSpec] = [
        GridSpec(rows: 1, cols: 2), GridSpec(rows: 1, cols: 3), GridSpec(rows: 1, cols: 4),
        GridSpec(rows: 2, cols: 2), GridSpec(rows: 2, cols: 3), GridSpec(rows: 2, cols: 4),
    ]
    /// 팝오버 한 줄에 놓을 타일 수
    static let tilesPerRow = 3

    @Published var targetApp: NSRunningApplication?
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var gap: Double {
        didSet { UserDefaults.standard.set(gap, forKey: "gap") }
    }

    var onApplied: (() -> Void)?

    private var observer: NSObjectProtocol?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init() {
        gap = UserDefaults.standard.object(forKey: "gap") as? Double ?? 8
        targetApp = NSWorkspace.shared.frontmostApplication
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != self.ownPID
            else { return }
            self.targetApp = app
        }
    }

    func refreshTarget() {
        accessibilityGranted = AXIsProcessTrusted()
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            targetApp = front
        }
    }

    func apply(grid: GridSpec, row: Int, col: Int) {
        guard let app = targetApp else { NSSound.beep(); return }
        WindowMover.move(appPID: app.processIdentifier, grid: grid, row: row, col: col, gap: CGFloat(gap))
        onApplied?()
    }
}
