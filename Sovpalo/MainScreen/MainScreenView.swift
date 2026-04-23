import SwiftUI

struct MainScreenView: View {
    @ObservedObject var presenter: MainScreenPresenter
    let interactor: MainScreenInteractor
    

    @State private var showAddBubble: Bool = false
    @State private var navigateToFreeTime: Bool = false
    @State private var selectedTab: TabBar.Tab = .home
    @State private var weeklyAvailability: [String: [Int]] = [:]

    var body: some View {
        NavigationStack {
           
            ZStack {
             
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                          
                            MeetingsSection(presenter: presenter)
                           freeTimeSection()
                            BestTimeCard(presenter: presenter)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 160)
                    }
                    Spacer()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                }

              
                floatingButtonInset

               
                if showAddBubble {
                    bubbleView
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.15), value: showAddBubble)
                }

                NavigationLink(
                    isActive: $navigateToFreeTime,
                    destination: {
                        FreeTimeEditorView(
                            selectedDate: selectedDateForEditor,
                            initialHoursByDate: weeklyAvailability
                        ) { hoursByDate in
                            interactor.updateMyFreeHours(forWeek: hoursByDate, selectedDateId: presenter.selectedDateId)
                        }
                    },
                    label: { EmptyView() }
                )
                .hidden()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                calendarSection()
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 0)
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
                            let isSelected: Bool = (date.id == presenter.selectedDateId)
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
   
 @ViewBuilder
    func freeTimeSection() -> some View {
        // Config
        let calendar: Calendar = .current
        let isSelectedDateToday = calendar.isDateInToday(selectedDateForEditor)
        let currentHour: Int? = isSelectedDateToday ? calendar.component(.hour, from: Date()) : nil
        let hours: [Int] = isSelectedDateToday ? Array((currentHour ?? 0)...23) : Array(0...23)

        // Layout constants
        let leftColumnWidth: CGFloat = adaptiveLeftColumnWidth(for: presenter.friends)
        let cellWidth: CGFloat = 36   // width per hour cell (kept stable)
        let cellSpacing: CGFloat = 16 // spacing between hour cells
        let contentLeadingPadding: CGFloat = 14
        let headerTopPadding: CGFloat = 12

        // Helper to compute total width of the hour strip
        let totalContentWidth: CGFloat = {
            let count = hours.count
            guard count > 0 else { return 0 }
            let cellsWidth: CGFloat = CGFloat(count) * cellWidth
            let gaps: CGFloat = CGFloat(max(0, count - 1)) * cellSpacing
            // We start content with some leading padding to match your design
            return contentLeadingPadding + cellsWidth + gaps + contentLeadingPadding
        }()

        let headerHeight: CGFloat = 30
        let rowBarHeight: CGFloat = 10
        let rowSpacing: CGFloat = 14
        let bottomPadding: CGFloat = 14
        let friendsCount: Int = presenter.friends.count
        let labelRowHeight: CGFloat = 24
        let verticalStackHeight: CGFloat =
            CGFloat(headerHeight) +
            rowSpacing +
            CGFloat(friendsCount) * labelRowHeight +
            CGFloat(max(0, friendsCount - 1)) * rowSpacing +
            bottomPadding

        FreeTimeCardView(
            friends: presenter.friends,
            hours: hours,
            currentHour: currentHour,
            isSyncing: presenter.isFreeTimeSyncing,
            leftColumnWidth: leftColumnWidth,
            cellWidth: cellWidth,
            cellSpacing: cellSpacing,
            contentLeadingPadding: contentLeadingPadding,
            headerTopPadding: headerTopPadding,
            headerHeight: headerHeight,
            rowBarHeight: rowBarHeight,
            rowSpacing: rowSpacing,
            bottomPadding: bottomPadding,
            totalContentWidth: totalContentWidth,
            verticalStackHeight: verticalStackHeight
        )
    }

    func adaptiveLeftColumnWidth(for friends: [MainScreen.Friend]) -> CGFloat {
        let minWidth: CGFloat = 100
        let maxWidth: CGFloat = 156
        let avatarWidth: CGFloat = 32
        let avatarSpacing: CGFloat = 8
        let horizontalPadding: CGFloat = 28

        let font = UIFont.preferredFont(forTextStyle: .body)
        let widestName = friends
            .map(\.name)
            .map { name in
                ceil((name as NSString).size(withAttributes: [.font: font]).width)
            }
            .max() ?? 0

        let desiredWidth = horizontalPadding + avatarWidth + avatarSpacing + widestName
        return min(max(minWidth, desiredWidth), maxWidth)
    }

    private func isFriendFree(_ friend: MainScreen.Friend, at hour: Int) -> Bool {
        // We only have freeHours in the model; consider an hour "free" if it is listed.
        friend.freeHours.contains(hour)
    }

    var floatingButtonInset: some View {
        VStack {
            Spacer()

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
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showAddBubble.toggle()
                        }
                    }

                Image(systemName: "sparkles")
                    .foregroundColor(.brandBlue)
                    .font(.title)
                    .bold()
            }
            .padding(.bottom, AppLayout.floatingButtonBottomOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard)
    }

    var bubbleView: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        Task {
                            weeklyAvailability = await interactor.fetchMyCurrentWeekHours(for: presenter.selectedDateId)
                            navigateToFreeTime = true
                        }
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showAddBubble = false
                        }
                    } label:  {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.bold))
                            Text("Добавить свое свободное время")
                                .font(.headline)
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 22)
                        .padding(.horizontal, 26)
                        .frame(minWidth: 320)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
                        )
                    }
                }
                Spacer()
            }
            .padding(.bottom, AppLayout.bubbleBottomOffset)
        }
        .background(
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showAddBubble = false
                    }
                }
        )
    }

    var selectedDateForEditor: Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: presenter.selectedDateId) ?? Date()
    }
}

struct FreeTimeCardView: View {
    let friends: [MainScreen.Friend]
    let hours: [Int]
    let currentHour: Int?
    let isSyncing: Bool

    let leftColumnWidth: CGFloat
    let cellWidth: CGFloat
    let cellSpacing: CGFloat
    let contentLeadingPadding: CGFloat
    let headerTopPadding: CGFloat

    let headerHeight: CGFloat
    let rowBarHeight: CGFloat
    let rowSpacing: CGFloat
    let bottomPadding: CGFloat
    let totalContentWidth: CGFloat
    let verticalStackHeight: CGFloat

    private let labelRowHeight: CGFloat = 24
    
    private var firstRelevantHour: Int? {
        friends
            .flatMap(\.freeHours)
            .min()
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            content
        }
        .overlay {
            if isSyncing {
                FreeTimeCardShimmer()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
        )
    }

    private var header: some View {
        HStack {
            Text("Свободное время друзей")
                .font(.title2.bold())
            if isSyncing {
                Text("Обновляем...")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.systemGray6))
                    )
            }
            Spacer()
        }
        .padding(.top, headerTopPadding)
        .padding(.horizontal, 14)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 0) {
            leftColumn
                .frame(width: leftColumnWidth, alignment: .leading)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HoursHeaderRow(
                            hours: hours,
                            currentHour: currentHour,
                            cellWidth: cellWidth,
                            cellSpacing: cellSpacing,
                            contentLeadingPadding: contentLeadingPadding,
                            height: headerHeight
                        )
                        .frame(height: headerHeight, alignment: .center)

                        VStack(spacing: rowSpacing) {
                            ForEach(friends, id: \.id) { friend in
                                FriendTimelineRow(
                                    isMe: friend.isMe,
                                    hours: hours,
                                    freeHours: friend.freeHours,
                                    cellWidth: cellWidth,
                                    cellSpacing: cellSpacing,
                                    contentLeadingPadding: contentLeadingPadding,
                                    barHeight: rowBarHeight
                                )
                                .frame(height: labelRowHeight, alignment: .center)
                                .padding(.trailing, 8)
                            }
                        }
                        .padding(.top, rowSpacing)
                        .padding(.bottom, bottomPadding)
                    }
                    .frame(width: totalContentWidth, height: verticalStackHeight, alignment: .topLeading)
                }
                .contentMargins(.horizontal, 0)
                .onAppear {
                    scrollToRelevantHour(using: proxy)
                }
                .onChange(of: hours) { _, _ in
                    scrollToRelevantHour(using: proxy)
                }
                .onChange(of: friends.map(\.freeHours)) { _, _ in
                    scrollToRelevantHour(using: proxy)
                }
            }
        }
    }

    private func scrollToRelevantHour(using proxy: ScrollViewProxy) {
        guard let targetHour = firstRelevantHour ?? currentHour, hours.contains(targetHour) else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo("hour-\(targetHour)", anchor: .leading)
            }
        }
    }

    private var leftColumn: some View {
        VStack(spacing: rowSpacing) {
            Color.clear
                .frame(height: headerHeight)

            ForEach(friends, id: \.id) { friend in
                FriendLabelRow(friend: friend)
                    .frame(height: labelRowHeight, alignment: .center)
            }
        }
        .padding(.bottom, bottomPadding)
    }
}

private struct FreeTimeCardShimmer: View {
    @State private var phase: CGFloat = -1.1

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.18),
                    .white.opacity(0.55),
                    .white.opacity(0.18),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 1.4)
            .rotationEffect(.degrees(14))
            .offset(x: proxy.size.width * phase)
            .onAppear {
                phase = -1.1
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    phase = 1.1
                }
            }
        }
        .background(Color.white.opacity(0.08))
    }
}

private struct HoursHeaderRow: View {
    let hours: [Int]
    let currentHour: Int?
    let cellWidth: CGFloat
    let cellSpacing: CGFloat
    let contentLeadingPadding: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: cellSpacing) {
            Color.clear.frame(width: contentLeadingPadding, height: 1)
            ForEach(hours, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundColor(hour == currentHour ? .blue : .secondary)
                    .frame(width: cellWidth, alignment: .center)
                    .id("hour-\(hour)")
            }
            Color.clear.frame(width: contentLeadingPadding, height: 1)
        }
        .frame(height: height)
    }
}

private struct FriendLabelRow: View {
    let friend: MainScreen.Friend

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(friend.isMe ? Color.brandBlue : Color(.systemGray5))
                Text(friend.avatarLetter)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(friend.isMe ? .white : .primary)
            }
            .frame(width: 32, height: 32)

            Text(friend.name)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }
}

private struct FriendTimelineRow: View {
    let isMe: Bool
    let hours: [Int]
    let freeHours: [Int]
    let cellWidth: CGFloat
    let cellSpacing: CGFloat
    let contentLeadingPadding: CGFloat
    let barHeight: CGFloat

    var body: some View {
        HStack(spacing: cellSpacing) {
            Color.clear.frame(width: contentLeadingPadding, height: 1)

            ForEach(hours, id: \.self) { hour in
                Capsule()
                    .fill(freeHours.contains(hour)
                          ? (isMe ? Color.brandBlue : Color.purple.opacity(0.8))
                          : Color(.systemGray5))
                    .frame(width: cellWidth, height: barHeight)
            }

            Color.clear.frame(width: contentLeadingPadding, height: 1)
        }
        .frame(height: barHeight)
    }
}



#Preview {
    let mockCompany = Company(
        id: 1,
        name: "Скалолазы",
        description: nil,
        createdBy: 1,
        createdAt: Date(),
        updatedAt: Date()
    )
    let presenter = MainScreenPresenter(company: mockCompany)
    let interactor = MainScreenInteractor(company: mockCompany, presenter: presenter)
    return MainScreenView(presenter: presenter, interactor: interactor)
}
