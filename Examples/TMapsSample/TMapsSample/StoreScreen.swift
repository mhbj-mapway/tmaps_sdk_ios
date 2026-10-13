import SwiftUI
import TMaps

private let heroHeight: CGFloat = 320

/// A shop page built around `TMap.showStatic`: the header is a real map, pinned on the shop
/// and frozen, so it reads as a photo of where the place is.
@MainActor
struct StoreScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let store = Store.darZaytoun
    /// How far the header has scrolled away, 0…1. Drives the top bar.
    @State private var barOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    sheet
                        // Pulled up over the map so the page reads as a sheet lying on the picture.
                        .padding(.top, -28)
                }
            }
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)

            topBar
        }
        .background(Color.sand.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: header

    private var header: some View {
        // The whole point of the page: a real map, frozen on the shop.
        // SUNNY carries no hillshade layer, which suits a retail page.
        TMapSwiftUIView(styleURL: TMapStyle.sunny) { map in
            map.showStatic(store.position, zoom: 15.5,
                           marker: TMarkerOptions(position: store.position, title: store.name, snippet: store.address))
        }
        .frame(height: heroHeight)
        .overlay(alignment: .top) {
            // Just enough to keep the status-bar icons legible over a pale tile.
            LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: heroHeight * 0.22)
                .allowsHitTesting(false)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ScrollOffsetKey.self,
                                       value: -proxy.frame(in: .named("scroll")).minY)
            }
        )
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            barOpacity = min(max(offset / (heroHeight - 100), 0), 1)
        }
    }

    // MARK: top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.92), in: Circle())
            }
            .accessibilityLabel("Back")
            Spacer()
            // Belongs to the header, so it goes away with it.
            Text("Open · closes 19:00")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.onOliveContainer)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.oliveContainer, in: Capsule())
                .opacity(1 - barOpacity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.sand.opacity(barOpacity).ignoresSafeArea(edges: .top))
    }

    // MARK: sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            title.padding(.top, 20)
            quickActions.padding(.top, 20)
            Divider().padding(.top, 24)

            section("About") {
                Text(store.about).font(.subheadline).foregroundStyle(.secondary)
            }
            section("Known for") { specialties }
            section("Where to find us") { addressCard }
            section("Opening hours") { hours }

            Button { openURL(store.directionsURL) } label: {
                Label("Get directions", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.olive, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 24)

            Text("The header is a live map frozen with TMap.showStatic(): pinned, fixed zoom, every gesture off.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .background(
            Color.sand.clipShape(RoundedCorners(radius: 28))
        )
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.name).font(.title.bold())
            Text(store.tagline).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(i < Int(store.rating) ? Color.terracotta : Color.secondary.opacity(0.3))
                }
                Text("\(String(format: "%.1f", store.rating)) · \(store.reviews) reviews · \(store.priceLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
            .padding(.top, 8)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickAction(icon: "mappin.and.ellipse", label: "Directions") { openURL(store.directionsURL) }
            QuickAction(icon: "phone.fill", label: "Call") { openURL(store.phoneURL) }
            ShareLink(item: "\(store.name) — \(store.address)") {
                QuickActionLabel(icon: "square.and.arrow.up", label: "Share")
            }
            .buttonStyle(.plain)
        }
    }

    private var specialties: some View {
        // A simple wrapping row; FlowLayout-style tags.
        WrappingHStack(items: store.specialties) { item in
            Text(item)
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.secondary.opacity(0.35)))
        }
    }

    private var addressCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.circle.fill").foregroundStyle(Color.olive).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.address).font(.subheadline)
                Text(String(format: "%.5f, %.5f", store.position.latitude, store.position.longitude))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.sandContainer, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var hours: some View {
        let today = Store.todayIndex()
        return VStack(spacing: 6) {
            ForEach(Array(store.hours.enumerated()), id: \.offset) { index, entry in
                HStack {
                    Text(entry.day)
                        .foregroundStyle(index == today ? AnyShapeStyle(Color.olive) : AnyShapeStyle(.primary))
                    Spacer()
                    Text(entry.hours ?? "Closed")
                        .foregroundStyle(index == today ? AnyShapeStyle(Color.olive) : AnyShapeStyle(.secondary))
                }
                .font(.subheadline)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
        .padding(.top, 24)
    }
}

// MARK: - small pieces

private struct QuickAction: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { QuickActionLabel(icon: icon, label: label) }
            .buttonStyle(.plain)
    }
}

private struct QuickActionLabel: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.body)
            Text(label).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .foregroundStyle(Color.onOliveContainer)
        .background(Color.oliveContainer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Top corners only, so the sheet reads as lying on the map.
private struct RoundedCorners: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Wraps tags onto as many lines as needed (iOS 16 `Layout`).
private struct WrappingHStack<Item: Hashable, Cell: View>: View {
    let items: [Item]
    let cell: (Item) -> Cell

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { cell($0) }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
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

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let gap = rows[rows.count - 1].indices.isEmpty ? 0 : spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += size.width + gap
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
