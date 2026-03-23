import SwiftUI

struct CustomTabBar: View {
    let selectedTab: TabBar.Tab
    let onSelect: (TabBar.Tab) -> Void

    var body: some View {
        HStack(spacing: 55) {
            tabButton(icon: "clock", tab: .home)
            tabButton(icon: "calendar", tab: .calendar)
            tabButton(icon: "lightbulb", tab: .lightbulb)
            tabButton(icon: "person.2", tab: .people)
        }
        .padding(.top, 20)
        .padding(.bottom, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: -4)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func tabButton(icon: String, tab: TabBar.Tab) -> some View {
        Button {
            onSelect(tab)
        } label: {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .foregroundColor(selectedTab == tab ? Color(hex: "7079FB") : .secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

struct TabBar {
    enum Tab: Int {
        case home = 0
        case calendar = 1
        case lightbulb = 2
        case people = 3
    }
}
