import AppKit
import Combine

/// 화면을 0...1 비율로 나눈 한 칸. 원점은 좌상단.
struct LayoutCell: Hashable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

/// 레이아웃 하나. 균등 그리드도, 한 열이 세로 100%를 차지하는 형태도 셀 목록으로 표현한다.
struct LayoutSpec: Hashable, Identifiable {
    let id: String
    let name: String
    let cells: [LayoutCell]

    /// rows×cols 균등 그리드
    static func grid(rows: Int, cols: Int) -> LayoutSpec {
        let w = 1.0 / Double(cols)
        let h = 1.0 / Double(rows)
        var cells: [LayoutCell] = []
        for r in 0..<rows {
            for c in 0..<cols {
                cells.append(LayoutCell(x: Double(c) * w, y: Double(r) * h, w: w, h: h))
            }
        }
        return LayoutSpec(id: "grid-\(rows)x\(cols)", name: "\(rows)×\(cols)", cells: cells)
    }

    /// cols개 열 중 한쪽 끝 열이 세로 100%를 차지하고, 나머지 열은 rows행으로 나뉜다.
    /// 셀 수 = 1 + (cols - 1) * rows  (예: cols 4, rows 2 → 7칸)
    static func fullColumn(onLeft: Bool, cols: Int, rows: Int) -> LayoutSpec {
        let w = 1.0 / Double(cols)
        let h = 1.0 / Double(rows)
        var cells: [LayoutCell] = []

        // 세로 100% 열
        let fullX = onLeft ? 0.0 : 1.0 - w
        cells.append(LayoutCell(x: fullX, y: 0, w: w, h: 1))

        // 나머지 열을 rows행으로 분할. 그리드와 같은 행 우선(좌→우, 위→아래) 순서로 담는다.
        let range = onLeft ? 1..<cols : 0..<(cols - 1)
        for r in 0..<rows {
            for c in range {
                cells.append(LayoutCell(x: Double(c) * w, y: Double(r) * h, w: w, h: h))
            }
        }

        let side = onLeft ? "왼쪽" : "오른쪽"
        return LayoutSpec(
            id: "full-\(onLeft ? "l" : "r")-\(cols)x\(rows)",
            name: "\(side) 전체 높이 + \(rows)×\(cols - 1)",
            cells: cells
        )
    }

    /// rows개 행 중 한쪽 끝 행이 가로 100%를 차지하고, 나머지 행은 cols열로 나뉜다.
    /// 셀 수 = 1 + (rows - 1) * cols  (예: rows 4, cols 2 → 7칸). 세로 모니터용.
    static func fullRow(onTop: Bool, rows: Int, cols: Int) -> LayoutSpec {
        let h = 1.0 / Double(rows)
        let w = 1.0 / Double(cols)
        var cells: [LayoutCell] = []

        // 가로 100% 행
        let fullY = onTop ? 0.0 : 1.0 - h
        cells.append(LayoutCell(x: 0, y: fullY, w: 1, h: h))

        // 나머지 행을 cols열로 분할 (행 우선)
        let range = onTop ? 1..<rows : 0..<(rows - 1)
        for r in range {
            for c in 0..<cols {
                cells.append(LayoutCell(x: Double(c) * w, y: Double(r) * h, w: w, h: h))
            }
        }

        let side = onTop ? "위" : "아래"
        return LayoutSpec(
            id: "fullrow-\(onTop ? "t" : "b")-\(rows)x\(cols)",
            name: "\(side) 전체 너비 + \(rows - 1)×\(cols)",
            cells: cells
        )
    }
}

extension LayoutSpec {
    /// 창 수가 칸 수보다 적을 때, 남는 칸을 맞닿은 칸에 합쳐 화면이 비지 않게 한다.
    /// 예) 5칸 레이아웃에 창 3개 → 왼쪽 전체 높이 + 가운데/오른쪽 열도 각각 전체 높이.
    /// 합칠 곳이 없으면 그 칸은 그냥 비워 둔다.
    static func fitted(cells: [LayoutCell], to count: Int) -> [LayoutCell] {
        guard count > 0 else { return [] }
        guard count < cells.count else { return cells }

        var used = Array(cells.prefix(count))
        var leftover = Array(cells.dropFirst(count))

        while !leftover.isEmpty {
            // 남는 칸을 쓰는 칸에 붙여 본다.
            if mergeLeftover(&leftover, into: &used) { continue }
            // 붙일 곳이 없으면 남는 칸끼리 먼저 합쳐 더 큰 덩어리로 만든다.
            if mergeLeftoverTogether(&leftover) { continue }
            break
        }
        return used
    }

    private static let epsilon = 0.0001

    /// a에 b를 붙일 수 있으면 합친 칸을 돌려준다. 같은 열에서 위아래로, 또는 같은 행에서 좌우로만 붙인다.
    private static func merging(_ a: LayoutCell, _ b: LayoutCell) -> LayoutCell? {
        if abs(a.x - b.x) < epsilon, abs(a.w - b.w) < epsilon {
            if abs(a.y + a.h - b.y) < epsilon { return LayoutCell(x: a.x, y: a.y, w: a.w, h: a.h + b.h) }
            if abs(b.y + b.h - a.y) < epsilon { return LayoutCell(x: a.x, y: b.y, w: a.w, h: a.h + b.h) }
        }
        if abs(a.y - b.y) < epsilon, abs(a.h - b.h) < epsilon {
            if abs(a.x + a.w - b.x) < epsilon { return LayoutCell(x: a.x, y: a.y, w: a.w + b.w, h: a.h) }
            if abs(b.x + b.w - a.x) < epsilon { return LayoutCell(x: b.x, y: a.y, w: a.w + b.w, h: a.h) }
        }
        return nil
    }

    private static func mergeLeftover(_ leftover: inout [LayoutCell], into used: inout [LayoutCell]) -> Bool {
        for (i, cell) in leftover.enumerated() {
            for j in used.indices {
                if let merged = merging(used[j], cell) {
                    used[j] = merged
                    leftover.remove(at: i)
                    return true
                }
            }
        }
        return false
    }

    private static func mergeLeftoverTogether(_ leftover: inout [LayoutCell]) -> Bool {
        for i in leftover.indices {
            for j in leftover.indices where j > i {
                if let merged = merging(leftover[i], leftover[j]) {
                    leftover[i] = merged
                    leftover.remove(at: j)
                    return true
                }
            }
        }
        return false
    }
}

/// 팝오버의 탭. 가로 모니터용/세로 모니터용 레이아웃 목록을 따로 가진다.
enum LayoutOrientation: String, CaseIterable, Identifiable {
    case landscape, portrait
    var id: String { rawValue }

    var title: String { self == .landscape ? "가로" : "세로" }
    var symbol: String { self == .landscape ? "rectangle" : "rectangle.portrait" }

    /// 탭에 표시할 레이아웃. tilesPerRow개씩 끊어 두 줄로 놓인다.
    var layouts: [LayoutSpec] {
        switch self {
        case .landscape:
            // 윗줄: 1행 분할 + 왼쪽 전체 높이 변형(5칸, 7칸)
            // 아랫줄: 2행 분할 + 오른쪽 전체 높이 변형(5칸, 7칸)
            return [
                .grid(rows: 1, cols: 2), .grid(rows: 1, cols: 3), .grid(rows: 1, cols: 4),
                .fullColumn(onLeft: true, cols: 3, rows: 2),
                .fullColumn(onLeft: true, cols: 4, rows: 2),
                .grid(rows: 2, cols: 2), .grid(rows: 2, cols: 3), .grid(rows: 2, cols: 4),
                .fullColumn(onLeft: false, cols: 3, rows: 2),
                .fullColumn(onLeft: false, cols: 4, rows: 2),
            ]
        case .portrait:
            // 뒤쪽 넷은 한쪽 끝 행이 가로 100%인 5칸·7칸 레이아웃(위/아래)
            return [
                .grid(rows: 2, cols: 1), .grid(rows: 3, cols: 1), .grid(rows: 4, cols: 1),
                .grid(rows: 2, cols: 2), .grid(rows: 3, cols: 2), .grid(rows: 4, cols: 2),
                .fullRow(onTop: true, rows: 3, cols: 2),
                .fullRow(onTop: false, rows: 3, cols: 2),
                .fullRow(onTop: true, rows: 4, cols: 2),
                .fullRow(onTop: false, rows: 4, cols: 2),
            ]
        }
    }

    /// 한 줄에 놓을 타일 수. 세로 탭은 6개를 한 줄에 모두 놓는다.
    var tilesPerRow: Int { self == .landscape ? 5 : 10 }

    /// 타일의 셀 영역 크기(카드 패딩 제외). 가로는 16:9, 세로는 9:16.
    var tileSize: CGSize {
        switch self {
        case .landscape: return CGSize(width: 116, height: 65)
        case .portrait:  return CGSize(width: 48, height: 85)
        }
    }
}

final class LayoutModel: ObservableObject {
    @Published var orientation: LayoutOrientation {
        didSet {
            guard oldValue != orientation else { return }
            UserDefaults.standard.set(orientation.rawValue, forKey: "orientation")
            // 팝오버 크기를 즉시(같은 프레임에) 맞춘다. 늦추면 한 프레임 동안 크기가 어긋나 깜빡인다.
            onLayoutChanged?()
        }
    }
    @Published var targetApp: NSRunningApplication?
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var gap: Double {
        didSet { UserDefaults.standard.set(gap, forKey: "gap") }
    }

    var onApplied: (() -> Void)?
    /// 탭 전환 등으로 팝오버 내용 크기가 바뀔 때 호출(AppDelegate가 팝오버 크기를 갱신)
    var onLayoutChanged: (() -> Void)?

    private var observer: NSObjectProtocol?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init() {
        gap = UserDefaults.standard.object(forKey: "gap") as? Double ?? 8
        orientation = LayoutOrientation(rawValue: UserDefaults.standard.string(forKey: "orientation") ?? "") ?? .landscape
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
        // 대상 창이 놓인 모니터 방향에 맞춰 탭을 자동 선택(세로 모니터면 세로 탭)
        if let app = targetApp, let portrait = WindowMover.isFocusedWindowOnPortraitScreen(appPID: app.processIdentifier) {
            orientation = portrait ? .portrait : .landscape
        }
    }

    /// 현재 화면의 창들을 이 레이아웃대로 한 번에 배치한다.
    func arrange(spec: LayoutSpec) {
        let placed = WindowMover.arrange(cells: spec.cells, gap: CGFloat(gap), on: WindowMover.currentScreen())
        if placed > 0 {
            onApplied?()
        } else {
            NSSound.beep()   // 배치할 창이 없으면 팝오버를 닫지 않는다
        }
    }

    func apply(cell: LayoutCell) {
        guard let app = targetApp else { NSSound.beep(); return }
        WindowMover.move(appPID: app.processIdentifier, cell: cell, gap: CGFloat(gap))
        onApplied?()
    }
}
