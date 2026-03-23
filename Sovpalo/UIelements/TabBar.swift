import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: TabBar.Tab

    var body: some View {
        HStack(spacing: 55) {
            tabButton(icon: "clock", tab: .home)
            tabButton(icon: "calendar", tab: .calendar)
            tabButton(icon: "lightbulb", tab: .lightbulb)
            tabButton(icon: "person.2", tab: .people)
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: -4)
        )
        .padding(.horizontal, -5)
        
    }

    @ViewBuilder
    private func tabButton(icon: String, tab: TabBar.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .foregroundColor(selectedTab == tab ? Color(hex: "7079FB") : .secondary)
        }
    }
}

struct TabBar {
    enum Tab: Int {
        case home, calendar, lightbulb, people
    }
}

// Simple hex color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a,r,g,b) = (255,(int>>16)&0xFF,(int>>8)&0xFF,int&0xFF)
        case 8: (a,r,g,b) = ((int>>24)&0xFF,(int>>16)&0xFF,(int>>8)&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// Preview
struct CustomTabBar_Previews: PreviewProvider {
    @State static var selected: TabBar.Tab = .home

    static var previews: some View {
        CustomTabBar(selectedTab: $selected)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
