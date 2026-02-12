import SwiftUI

struct ListFriendsView: View {
    struct Friend: Identifiable {
        let id = UUID()
        let name: String
        let letter: String
        let isMe: Bool
        let availability: CGFloat // 0...1
    }
    private let friends: [Friend] = [
        .init(name: "Я",   letter: "Я", isMe: true,  availability: 0.62),
        .init(name: "Миа", letter: "М", isMe: false, availability: 0.50),
        .init(name: "Теа", letter: "Т", isMe: false, availability: 0.56),
        .init(name: "Ана", letter: "А", isMe: false, availability: 0.52)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Скалолазы")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            // Free time card like on MainScreen
            VStack(spacing: 12) {
                // Header inside the card (title + small controls icon)
                HStack {
                    Text("Свободное время друзей")
                        .font(.title2.bold())
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
                .padding(.horizontal, 14)

                // Compact hours row (09–20)
                let hours = (9...20).map { String(format: "%02d", $0) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Empty width to align with avatar+name column below
                        Color.clear.frame(width: 70, height: 1)
                        ForEach(hours, id: \.self) { hour in
                            Text(hour)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                }

                // Rows: avatar + name + colored bar like on main screen
                VStack(spacing: 14) {
                    ForEach(friends) { friend in
                        HStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(friend.isMe ? Color.brandBlue : Color(.systemGray5))
                                Text(friend.letter)
                                    .font(.footnote.weight(.bold))
                                    .foregroundColor(friend.isMe ? .white : .primary)
                            }
                            .frame(width: 32, height: 32)

                            // Name
                            Text(friend.name)
                                .font(.body)
                                .frame(width: 38, alignment: .leading)

                            // Timeline bar
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.systemGray5))
                                Capsule().fill(friend.isMe ? Color.brandBlue : Color.purple.opacity(0.8))
                                    .frame(width: 140)
                                    .padding(.leading, friend.isMe ? 40 : 20)
                            }
                            .frame(height: 10)
                            .padding(.trailing, 8)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
            )
            .padding(.horizontal, 20)

            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    ListFriendsView()
}

