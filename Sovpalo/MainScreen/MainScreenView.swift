import SwiftUI

struct MainScreenView: View {
    @ObservedObject var presenter: MainScreenPresenter
    let interactor: MainScreenInteractor

    // MARK: - Local UI state for bubble and navigation
    @State private var showAddBubble: Bool = false
    @State private var navigateToFreeTime: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Main rounded container
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {

                            // Sections requiring presenter
                            MeetingsSection(presenter: presenter)
                            freeTimeSection()
                            BestTimeCard(presenter: presenter)

                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 160) // leave room for centered FAB + bubble
                    }
                    Spacer()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                }

                // Floating button centered at bottom
                floatingButton
              
                // Enlarged bubble close to button
                if showAddBubble {
                    bubbleView
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.15), value: showAddBubble)
                }

                // Hidden navigation trigger
                NavigationLink(
                    destination: FreeTimeEditorView(),
                    isActive: $navigateToFreeTime
                ) { EmptyView() }
                .hidden()
            }
            .safeAreaInset(edge: .top) {
                calendarSection()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
            }
            .onAppear {
                interactor.load()
            }
            .onChange(of: navigateToFreeTime) { _, newValue in
                if newValue == false {
                    withAnimation(.spring) { showAddBubble = false }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private extension MainScreenView {
    @ViewBuilder
    func calendarSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(presenter.dates, id: \.id) { date in
                            let isSelected = date.id == presenter.selectedDateId
                            DatePill(
                                weekdayShort: date.weekdayShort,
                                dayNumber: date.dayNumber,
                                isToday: date.isToday,
                                isSelected: isSelected,
                                onTap: { interactor.selectDate(dateId: date.id) }
                            )
                            .id(date.id)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .onAppear {
                    if !presenter.selectedDateId.isEmpty {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(presenter.selectedDateId, anchor: .center)
                        }
                    }
                }
                .onChange(of: presenter.selectedDateId) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    // Refined "Свободное время друзей" card to look like one enclosed view
    @ViewBuilder
    func freeTimeSection() -> some View {
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

            // Compact hours row (mock 09–20 for visual alignment)
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

            // Rows: avatar + name + simple colored “bar” as a placeholder
            VStack(spacing: 14) {
                ForEach(presenter.friends, id: \.id) { friend in
                    HStack(spacing: 12) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(friend.isMe ? Color.brandBlue : Color(.systemGray5))
                            Text(friend.avatarLetter)
                                .font(.footnote.weight(.bold))
                                .foregroundColor(friend.isMe ? .white : .primary)
                        }
                        .frame(width: 32, height: 32)

                        // Name
                        Text(friend.name)
                            .font(.body)
                            .frame(width: 38, alignment: .leading) // keeps columns aligned

                        // Placeholder timeline bar
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5))
                            // A sample colored segment to suggest availability
                            Capsule().fill(friend.isMe ? Color.brandBlue : Color.purple.opacity(0.8))
                                .frame(width: 140) // tweak to taste
                                .padding(.leading, friend.isMe ? 40 : 20) // offset to vary
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
    }

    // Centered FAB with sparkles
    var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Color.clear
                    .frame(width: 1, height: 1)
                Spacer()
            }
            .overlay(
                ZStack {
                    Circle()
                        .fill(Color.brandYellow)
                        .frame(width: 74, height: 74)
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray4), lineWidth: 0.6)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.15)) {
                                showAddBubble.toggle()
                            }
                        }

                    Image(systemName: "sparkles")
                        .foregroundColor(.brandBlue)
                        .font(.title)
                        .bold()
                }
                .padding(.bottom, 34),
                alignment: .center
            )
        }
        .ignoresSafeArea(.keyboard)
    }

    // Enlarged bubble closer to the button
    var bubbleView: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        navigateToFreeTime = true
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showAddBubble = false
                        }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.bold))
                            Text("Добавить свое свободное время")
                                .font(.headline)
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 22)
                        .padding(.horizontal, 26)
                        .frame(minWidth: 320) // wider
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
                        )
                    }
                }
                Spacer()
            }
            .padding(.bottom, 98) // bring it closer to the button
        }
        .background(
            // Tap outside to dismiss
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showAddBubble = false
                    }
                }
        )
    }
}

