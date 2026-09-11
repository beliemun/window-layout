import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var model: LayoutModel

    static let width: CGFloat = 500
    static let tileHeight: CGFloat = 88
    static let tileSpacing: CGFloat = 12
    static let portraitTileWidth: CGFloat = 84

    /// tilesPerRow개씩 묶어 줄을 만든다.
    private var gridRows: [[GridSpec]] {
        let n = LayoutModel.tilesPerRow
        return stride(from: 0, to: LayoutModel.grids.count, by: n).map {
            Array(LayoutModel.grids[$0..<min($0 + n, LayoutModel.grids.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !model.accessibilityGranted {
                accessibilityWarning
            }

            // LazyVGrid는 팝오버 표시 후에 크기를 늦게 보고해 팝오버가 위로 밀리므로 사용하지 않는다.
            HStack(alignment: .top, spacing: Self.tileSpacing) {
                VStack(spacing: Self.tileSpacing) {
                    ForEach(gridRows, id: \.self) { line in
                        HStack(spacing: Self.tileSpacing) {
                            ForEach(line) { grid in
                                GridTile(grid: grid, height: Self.tileHeight) { row, col in
                                    model.apply(grid: grid, row: row, col: col)
                                }
                            }
                        }
                    }
                }
                // 세로 모니터용 그리드: 두 줄 높이의 세로 타일
                let portraitHeight = Self.tileHeight * CGFloat(gridRows.count)
                    + Self.tileSpacing * CGFloat(max(gridRows.count - 1, 0))
                ForEach(LayoutModel.portraitGrids) { grid in
                    GridTile(grid: grid, height: portraitHeight, width: Self.portraitTileWidth) { row, col in
                        model.apply(grid: grid, row: row, col: col)
                    }
                }
            }

            VStack(spacing: 0) {
                Divider()
                GapRow(gap: $model.gap)
                Divider()
                LoginItemRow()
                Divider()
                MenuRow(title: "Quit", shortcut: "⌘ Q") { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = model.targetApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "macwindow")
                    .frame(width: 22, height: 22)
            }
            Text(model.targetApp?.localizedName ?? "창 없음")
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
            Spacer()
        }
    }

    private var accessibilityWarning: some View {
        Button {
            AccessibilityAccess.requestIfNeeded()
            AccessibilityAccess.openSystemSettings()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text("손쉬운 사용 권한이 필요합니다. 클릭해서 설정 열기")
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

/// rows×cols 그리드 하나. 각 셀을 클릭하면 onSelect(row, col)이 호출된다.
struct GridTile: View {
    let grid: GridSpec
    var height: CGFloat = 88
    var width: CGFloat? = nil
    let onSelect: (Int, Int) -> Void

    @State private var hovered: (row: Int, col: Int)? = nil

    private let spacing: CGFloat = 5

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<grid.rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<grid.cols, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
        .frame(width: width, height: height)
    }

    private func cell(row: Int, col: Int) -> some View {
        let isHovered = hovered?.row == row && hovered?.col == col
        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(isHovered ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.12))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { inside in
                hovered = inside ? (row, col) : nil
            }
            .onTapGesture { onSelect(row, col) }
            .help("\(grid.rows)×\(grid.cols) — \(row + 1)행 \(col + 1)열")
    }
}

struct MenuRow: View {
    let title: String
    let shortcut: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 15))
                Spacer()
                Text(shortcut).font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovered ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

/// 창 간격(px) 조절 줄: 슬라이더 + −/+ 버튼
struct GapRow: View {
    @Binding var gap: Double

    var body: some View {
        HStack(spacing: 8) {
            Text("창 간격").font(.system(size: 15))
            Spacer()
            stepButton("minus") { gap = max(0, gap - 1) }
            // step:을 주면 macOS 슬라이더가 눈금(점)을 그리므로, 눈금 없이 값만 정수로 반올림한다.
            Slider(value: Binding(get: { gap }, set: { gap = $0.rounded() }), in: 0...32)
                .frame(width: 110)
            stepButton("plus") { gap = min(32, gap + 1) }
            Text("\(Int(gap)) px")
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

/// 로그인 시 자동 실행 토글
struct LoginItemRow: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("로그인 시 자동 실행").font(.system(size: 15))
                Spacer()
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .onChange(of: enabled) { on in
                do {
                    if on { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                    error = nil
                } catch {
                    self.error = error.localizedDescription
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .onAppear { enabled = SMAppService.mainApp.status == .enabled }
    }
}
