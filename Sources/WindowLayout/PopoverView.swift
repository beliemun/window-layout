import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var model: LayoutModel

    static let width: CGFloat = 540
    static let padding: CGFloat = 14
    static let tileSpacing: CGFloat = 8

    /// 탭의 타일 영역 높이. 탭 전환 시 팝오버 크기를 한 프레임 안에 맞추기 위해 직접 계산한다.
    static func tilesHeight(for orientation: LayoutOrientation) -> CGFloat {
        let rows = Int(ceil(Double(orientation.layouts.count) / Double(orientation.tilesPerRow)))
        let cardHeight = orientation.tileSize.height + LayoutTile.cardPadding * 2
        return CGFloat(rows) * cardHeight + CGFloat(max(rows - 1, 0)) * tileSpacing
    }

    /// 현재 탭의 레이아웃을 tilesPerRow개씩 묶어 줄을 만든다.
    private var tileRows: [[LayoutSpec]] {
        let layouts = model.orientation.layouts
        let n = model.orientation.tilesPerRow
        return stride(from: 0, to: layouts.count, by: n).map {
            Array(layouts[$0..<min($0 + n, layouts.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !model.accessibilityGranted {
                accessibilityWarning
            }

            tiles

            settingsGroup

            footer
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 헤더: 대상 앱 + 가로/세로 탭

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = model.targetApp?.icon {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: "macwindow").font(.system(size: 16)).frame(width: 24, height: 24)
            }
            Text(model.targetApp?.localizedName ?? "창 없음")
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            OrientationTabs(selection: $model.orientation)
        }
    }

    private var accessibilityWarning: some View {
        Button {
            AccessibilityAccess.requestIfNeeded()
            AccessibilityAccess.openSystemSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text("손쉬운 사용 권한이 필요합니다. 클릭해서 설정 열기")
                    .font(.system(size: 12))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.yellow.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: 타일

    private var tiles: some View {
        let tile = model.orientation.tileSize
        return VStack(spacing: Self.tileSpacing) {
            ForEach(tileRows, id: \.self) { line in
                HStack(spacing: Self.tileSpacing) {
                    ForEach(line) { spec in
                        LayoutTile(
                            spec: spec,
                            cellArea: tile,
                            onSelect: { cell in model.apply(cell: cell) },
                            onArrange: { model.arrange(spec: spec) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        // 탭을 바꿀 때 타일이 애니메이션되며 깜빡이지 않도록 즉시 교체한다.
        .animation(nil, value: model.orientation)
    }

    // MARK: 설정 그룹

    private var settingsGroup: some View {
        VStack(spacing: 0) {
            HStack {
                Label("창 간격", systemImage: "arrow.left.and.right.square")
                    .font(.system(size: 13))
                Spacer()
                GapStepper(gap: $model.gap)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)

            HStack {
                Label("로그인 시 자동 실행", systemImage: "power")
                    .font(.system(size: 13))
                Spacer()
                LoginItemToggle()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    // MARK: 푸터

    private var footer: some View {
        HStack {
            Text("WindowLayout \(Self.version)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button { NSApp.terminate(nil) } label: {
                HStack(spacing: 6) {
                    Text("종료").font(.system(size: 12, weight: .medium))
                    Text("⌘Q").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return v.isEmpty ? "" : "v\(v)"
    }
}

// MARK: - 가로/세로 캡슐 탭

struct OrientationTabs: View {
    @Binding var selection: LayoutOrientation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LayoutOrientation.allCases) { o in
                let selected = o == selection
                Button { selection = o } label: {
                    HStack(spacing: 4) {
                        Image(systemName: o.symbol)
                            .font(.system(size: 10, weight: .semibold))
                        Text(o.title).font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .background(
                        Capsule().fill(selected ? Color.primary.opacity(0.14) : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .animation(.easeOut(duration: 0.12), value: selection)
    }
}

// MARK: - 레이아웃 타일 (카드 안에 비율대로 배치된 셀)

struct LayoutTile: View {
    let spec: LayoutSpec
    /// 셀 영역 크기(카드 패딩 제외). 가로 16:9, 세로 9:16.
    let cellArea: CGSize
    let onSelect: (LayoutCell) -> Void
    /// 카드 모서리의 번개 버튼: 화면의 창들을 이 레이아웃으로 한 번에 배치
    let onArrange: () -> Void

    @State private var hoveredIndex: Int? = nil
    @State private var cardHovered = false

    static let cardPadding: CGFloat = 6
    private let cellGap: CGFloat = 3
    private var cardPadding: CGFloat { Self.cardPadding }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(spec.cells.enumerated()), id: \.offset) { item in
                cellView(index: item.offset, cell: item.element)
            }
        }
        .frame(width: cellArea.width, height: cellArea.height, alignment: .topLeading)
        .padding(cardPadding)
        .background(cardBackground)
        // .offset을 쓰지 않는다(히트 영역이 어긋남). overlay 정렬로 배치한다.
        .overlay(alignment: .topTrailing) {
            if cardHovered { arrangeButton }
        }
        .onHover { cardHovered = $0 }
        .help(spec.name)
    }

    private func cellView(index: Int, cell: LayoutCell) -> some View {
        let width: CGFloat = max(cellArea.width * CGFloat(cell.w) - cellGap, 2)
        let height: CGFloat = max(cellArea.height * CGFloat(cell.h) - cellGap, 2)
        let dx: CGFloat = cellArea.width * CGFloat(cell.x) + cellGap / 2
        let dy: CGFloat = cellArea.height * CGFloat(cell.y) + cellGap / 2
        let fill: Color = hoveredIndex == index ? Color.accentColor : Color.primary.opacity(0.16)

        // 히트 영역은 .offset 앞에서 정해야 한다. .offset 뒤에 contentShape를 붙이면
        // 클릭·호버 영역이 이동 전(레이아웃) 위치에 남아 엉뚱한 자리에서 반응한다.
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(fill)
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { hoveredIndex = index }
                else if hoveredIndex == index { hoveredIndex = nil }
            }
            .onTapGesture { onSelect(cell) }
            .offset(x: dx, y: dy)
    }

    private var arrangeButton: some View {
        Button(action: onArrange) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 15, height: 15)
                .background(Circle().fill(Color.accentColor))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(1)
        .help("현재 화면의 창들을 이 레이아웃으로 자동 배치")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(cardHovered ? 0.10 : 0.06))
    }
}

// MARK: - 창 간격 스테퍼 [ − | 8 px | + ]

struct GapStepper: View {
    @Binding var gap: Double

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus") { gap = max(0, gap - 1) }
            Text("\(Int(gap)) px")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .frame(width: 46)
            stepButton("plus") { gap = min(32, gap + 1) }
        }
        .background(Capsule().fill(Color.primary.opacity(0.08)))
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 로그인 시 자동 실행 토글

struct LoginItemToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("", isOn: $enabled)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: enabled) { on in
                do {
                    if on { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    NSLog("login item change failed: \(error.localizedDescription)")
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
            .onAppear { enabled = SMAppService.mainApp.status == .enabled }
    }
}
