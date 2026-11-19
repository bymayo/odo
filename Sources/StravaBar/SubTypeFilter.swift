import SwiftUI

/// Filter chips for the selected sport: types (Ride, Virtual Ride…) and tags (Commute, Race…)
struct SubTypeFilterChips: View {
    @ObservedObject var viewModel: StravaViewModel
    let sport: SportCategory

    var body: some View {
        let types = viewModel.subTypes(for: sport)
        let tags = viewModel.tags(for: sport)

        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 5) {
                allChip
                if types.count > 1 {
                    ForEach(types, id: \.self) { typeChip($0) }
                }
            }

            if !tags.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text("Tags")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, 5)
                    FlowLayout(spacing: 5) {
                        ForEach(tags, id: \.self) { tagChip($0) }
                    }
                }
            }
        }
    }

    private var allChip: some View {
        let active = !viewModel.isFiltering(sport)
        return Button(action: { viewModel.includeAllSubTypes(sport: sport) }) {
            chipLabel("All", icon: nil, style: active ? .filled : .outline)
        }
        .buttonStyle(.borderless)
        .help("Clear all filters")
    }

    private func typeChip(_ subType: String) -> some View {
        let included = viewModel.isSubTypeIncluded(subType, sport: sport)
        let name = subTypeDisplayName(subType)
        return Button(action: { viewModel.setSubType(subType, sport: sport, included: !included) }) {
            chipLabel(name, icon: included ? "checkmark" : "plus", style: included ? .on : .off)
        }
        .buttonStyle(.borderless)
        .overlay(RightClickCatcher { viewModel.soloSubType(subType, sport: sport) })
        .help("Click to toggle · right-click to show only \(name)")
    }

    private func tagChip(_ tag: String) -> some View {
        let mode = viewModel.tagMode(tag, sport: sport)
        let (icon, style, help): (String, ChipStyle, String) = {
            switch mode {
            case .any: return ("number", .on, "Click to hide \(tag)s · right-click to show only \(tag)s")
            case .exclude: return ("minus", .off, "\(tag)s hidden · click to include")
            case .only: return ("scope", .filled, "Only \(tag)s · right-click to undo")
            }
        }()
        return Button(action: { viewModel.toggleTag(tag, sport: sport) }) {
            chipLabel(mode == .only ? "Only \(tag)" : tag, icon: icon, style: style)
        }
        .buttonStyle(.borderless)
        .overlay(RightClickCatcher { viewModel.soloTag(tag, sport: sport) })
        .help(help)
    }

    private enum ChipStyle { case on, off, filled, outline }

    private func chipLabel(_ text: String, icon: String?, style: ChipStyle) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                    .opacity(style == .filled ? 1 : 0.7)
            }
            Text(text)
                .font(.system(size: 10, weight: style == .filled ? .medium : .regular))
                .strikethrough(style == .off, color: Theme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor({
            switch style {
            case .filled: return Theme.background
            case .on: return Theme.ink.opacity(0.8)
            case .off, .outline: return Theme.textTertiary
            }
        }())
        .background({
            switch style {
            case .filled: return Theme.ink
            case .on: return Theme.cardRaised
            case .off, .outline: return Color.clear
            }
        }())
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(style == .filled ? Color.clear : Theme.hairline, lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

/// Simple wrapping layout: places children left-to-right, wrapping onto new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

/// Transparent overlay that handles right-clicks only; every other event passes through.
struct RightClickCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.action = action
    }

    final class CatcherView: NSView {
        var action: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            switch NSApp.currentEvent?.type {
            case .rightMouseDown, .rightMouseUp: return super.hitTest(point)
            default: return nil
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            action?()
        }
    }
}
