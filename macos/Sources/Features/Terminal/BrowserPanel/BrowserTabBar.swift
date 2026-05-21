import SwiftUI

/// Thanh tab bar nằm trên cùng Browser panel. Mỗi tab có title (truncate) +
/// nút close (X) hiện khi hover. Cuối cùng là nút `+` để thêm tab.
struct BrowserTabBar: View {
    @ObservedObject var model: BrowserTabsModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(model.tabs) { tab in
                        BrowserTabPill(
                            tab: tab,
                            isActive: tab.id == model.activeTabID,
                            canClose: model.tabs.count > 1,
                            onSelect: { model.setActive(tab.id) },
                            onClose: { model.closeTab(tab.id) }
                        )
                        .id(tab.id)
                    }

                    Button(action: { model.addTab() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                            .frame(width: 22, height: 22)
                            .background(Color(red: 0.16, green: 0.16, blue: 0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("New tab")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .onChange(of: model.activeTabID) { newID in
                guard let id = newID else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }
}

/// Một pill trong tab bar. Observe tab để re-render khi title đổi.
private struct BrowserTabPill: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    /// Không cho close khi chỉ còn 1 tab (model sẽ tự re-create nếu close hết,
    /// nhưng UI giấu nút X để rõ ý đồ với user).
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(tab.displayTitle)
                .font(.system(size: 11))
                .foregroundColor(isActive ? .white : Color(red: 0.75, green: 0.75, blue: 0.75))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 140, alignment: .leading)

            if canClose && (isHovered || isActive) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(red: 0.8, green: 0.8, blue: 0.8))
                        .frame(width: 14, height: 14)
                        .background(
                            Circle().fill(isHovered ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Close tab")
            } else {
                // Giữ chỗ để layout không nhảy khi unhover.
                Color.clear.frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive
                      ? Color(red: 0.22, green: 0.22, blue: 0.22)
                      : Color(red: 0.13, green: 0.13, blue: 0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive
                        ? Color(red: 0.35, green: 0.35, blue: 0.35)
                        : Color(red: 0.20, green: 0.20, blue: 0.20),
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .help(tab.urlString)
    }
}
