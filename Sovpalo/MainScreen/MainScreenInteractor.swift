import Foundation

final class MainScreenInteractor {
    private let company: Company
    private let presenter: MainScreenPresenter
    private let availabilityWorker: GroupAvailabilityWorkerProtocol
    private let membersWorker: CompanyMembersWorkerProtocol
    private let userAvailabilityWorker: UserAvailabilityWorkerProtocol
    private let meetingsWorker: MeetingsWorkerProtocol
    private var cachedAvailability: [UserAvailability] = []
    private var cachedMembers: [CompanyMemberView] = []
    private var optimisticAvailabilityID: Int = -1

    init(
        company: Company,
        presenter: MainScreenPresenter,
        availabilityWorker: GroupAvailabilityWorkerProtocol = GroupAvailabilityWorker(),
        membersWorker: CompanyMembersWorkerProtocol = CompanyMembersWorker(),
        userAvailabilityWorker: UserAvailabilityWorkerProtocol = UserAvailabilityWorker(),
        meetingsWorker: MeetingsWorkerProtocol = MeetingsWorker()
    ) {
        self.company = company
        self.presenter = presenter
        self.availabilityWorker = availabilityWorker
        self.membersWorker = membersWorker
        self.userAvailabilityWorker = userAvailabilityWorker
        self.meetingsWorker = meetingsWorker

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMeetingDeleted),
            name: .meetingDeleted,
            object: nil
        )
    }

    @objc private func handleMeetingDeleted() {
        refreshMeetings()
    }

    private func refreshMeetings() {
        Task {
            let meetings = await fetchTodayMeetings()
            await MainActor.run {
                presenter.meetings = meetings
            }
        }
    }

    func load() {
        print("Loading MainScreen for company id: \(company.id), name: \(company.name)")

        presenter.dates = generateDatesForThreeMonths()

        if let today = presenter.dates.first(where: { $0.isToday }) {
            presenter.selectedDateId = today.id
        } else {
            presenter.selectedDateId = presenter.dates.first?.id ?? ""
        }

       
        

        Task {
            do {
                async let availabilityItems = availabilityWorker.fetchCompanyAvailability(companyID: Int(company.id))
                async let memberItems = membersWorker.fetchMembers(companyID: Int(company.id))
                async let meetingItems = fetchTodayMeetings()

                let (availability, members, todayMeetings) = try await (availabilityItems, memberItems, meetingItems)
                self.cachedAvailability = availability
                self.cachedMembers = members
                let friends = self.mapToFriends(
                    availability,
                    members: members,
                    dateId: self.presenter.selectedDateId
                )

                await MainActor.run {
                    presenter.friends = friends
                    presenter.bestTimeText = self.calculateBestTime(friends: friends)
                    presenter.todayTitle = "Встречи сегодня"
                    presenter.meetings = todayMeetings
                }
            } catch {
                print("Failed to fetch data: \(error)")
                await MainActor.run {
                    presenter.friends = demoFriends()
                    presenter.bestTimeText = self.calculateBestTime(friends: demoFriends())
                    presenter.todayTitle = "Встречи сегодня"
                    presenter.meetings = []
                }
            }
        }

        presenter.hours = ["09", "10", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21"]
    }
    
    private func mapToFriends(_ items: [UserAvailability], members: [CompanyMemberView], dateId: String) -> [MainScreen.Friend] {
       var currentUserID: Int {
            guard let data = KeychainService().getData(forKey: "auth.userId"),
                  let str = String(data: data, encoding: .utf8),
                  let id = Int(str) else { return -1 }
            return id
        }
            let calendar = Calendar.current
            let selectedDate = Self.date(from: dateId)
            let grouped = Dictionary(grouping: items, by: \.userID)

            return members.map { member in
                let intervals = grouped[member.userID] ?? []
                var freeHours: [Int] = []
                for interval in intervals {
                    guard let selectedDate, calendar.isDate(interval.startTime, inSameDayAs: selectedDate) else {
                        continue
                    }
                    let start = calendar.component(.hour, from: interval.startTime)
                    let end   = calendar.component(.hour, from: interval.endTime)
                    freeHours += Array(start...end)
                }
                let avatarLetter = String(member.username.prefix(1)).uppercased()
                return MainScreen.Friend(
                    id: String(member.userID),
                    name: member.username,
                    avatarLetter: avatarLetter,
                    isMe: member.userID == currentUserID, // replace with real currentUserID check if you store it
                    freeHours: freeHours.sorted()
                )
            }
        }
    private func fetchTodayMeetings() async -> [MainScreen.Meeting] {
        do {
            let events = try await meetingsWorker.fetchCompanyEvents(companyId: Int(company.id))
            print(">>> Total events from API: \(events.count)")
            
            let calendar = Calendar.current
            let today = Date()
            print(">>> Today is: \(today)")
            
            for event in events {
                print(">>> Event: \(event.title), startTime: \(event.startTime ?? "nil")")
            }
            
            let todayEvents = events.filter { event in
                guard let startTime = event.startTime else { return false }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard let date = formatter.date(from: startTime) else {
                    let basic = ISO8601DateFormatter()
                    basic.formatOptions = [.withInternetDateTime]
                    guard let d = basic.date(from: startTime) else {
                        print(">>> Could not parse date: \(startTime)")
                        return false
                    }
                    print(">>> Parsed date: \(d), isToday: \(calendar.isDate(d, inSameDayAs: today))")
                    return calendar.isDate(d, inSameDayAs: today)
                }
                print(">>> Parsed date: \(date), isToday: \(calendar.isDate(date, inSameDayAs: today))")
                return calendar.isDate(date, inSameDayAs: today)
            }
            
            print(">>> Today events count: \(todayEvents.count)")
            
            return todayEvents.map { event in
                let timeText = formatTime(from: event.startTime)
                return MainScreen.Meeting(
                    timeText: timeText,
                    title: event.title,
                    locationText: event.description ?? ""
                )
            }
        } catch {
            print(">>> Failed to fetch meetings: \(error)")
            return []
        }
    }
    private func formatTime(from dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            date = basic.date(from: dateString)
        }
        guard let parsed = date else { return "" }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return timeFormatter.string(from: parsed)
    }

    private func demoFriends() -> [MainScreen.Friend] {
          [
              MainScreen.Friend(id: "me",    name: "Я",   avatarLetter: "Я", isMe: true,  freeHours: Array(14...19)),
              MainScreen.Friend(id: "alena", name: "Миа", avatarLetter: "М", isMe: false, freeHours: Array(12...17)),
              MainScreen.Friend(id: "vanya", name: "Теа", avatarLetter: "Т", isMe: false, freeHours: Array(15...20)),
              MainScreen.Friend(id: "pasha", name: "Ана", avatarLetter: "А", isMe: false, freeHours: Array(13...18))
          ]
      }

    private var currentUserID: Int? {
        guard let data = KeychainService().getData(forKey: "auth.userId"),
              let str = String(data: data, encoding: .utf8),
              let id = Int(str) else { return nil }
        return id
    }

    private func makeAvailabilityInterval(
        companyID: Int,
        userID: Int,
        dayDate: Date,
        hours: [Int]
    ) -> UserAvailability? {
        guard let startHour = hours.min(), let endHour = hours.max() else { return nil }

        let calendar = Calendar.current
        var startComps = calendar.dateComponents([.year, .month, .day], from: dayDate)
        var endComps = calendar.dateComponents([.year, .month, .day], from: dayDate)
        startComps.hour = startHour
        startComps.minute = 0
        startComps.second = 0
        endComps.hour = endHour
        endComps.minute = 0
        endComps.second = 0

        guard let startTime = calendar.date(from: startComps),
              let endTime = calendar.date(from: endComps) else { return nil }

        defer { optimisticAvailabilityID -= 1 }
        return UserAvailability(
            id: optimisticAvailabilityID,
            userID: userID,
            companyID: companyID,
            startTime: startTime,
            endTime: endTime,
            note: nil
        )
    }

    private func applyOptimisticAvailabilityForDay(hours: [Int], dateId: String) {
        guard let userID = currentUserID,
              let selectedDate = Self.date(from: dateId) else { return }

        let companyID = Int(company.id)
        let calendar = Calendar.current

        cachedAvailability.removeAll {
            $0.userID == userID && calendar.isDate($0.startTime, inSameDayAs: selectedDate)
        }

        if let interval = makeAvailabilityInterval(
            companyID: companyID,
            userID: userID,
            dayDate: selectedDate,
            hours: hours
        ) {
            cachedAvailability.append(interval)
        }

        presenter.friends = mapToFriends(cachedAvailability, members: cachedMembers, dateId: dateId)
        presenter.bestTimeText = calculateBestTime(friends: presenter.friends)
    }

    private func applyOptimisticAvailabilityForWeek(hoursByDate: [String: [Int]], selectedDateId: String) {
        guard let userID = currentUserID,
              let selectedDate = Self.date(from: selectedDateId) else { return }

        let companyID = Int(company.id)
        let calendar = Calendar.current
        let weekStart = Self.startOfWeekMonday(for: selectedDate)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }

        cachedAvailability.removeAll {
            $0.userID == userID && $0.startTime >= weekStart && $0.startTime < weekEnd
        }

        for (dateId, hours) in hoursByDate.sorted(by: { $0.key < $1.key }) {
            guard !hours.isEmpty,
                  let dayDate = Self.date(from: dateId),
                  let interval = makeAvailabilityInterval(
                    companyID: companyID,
                    userID: userID,
                    dayDate: dayDate,
                    hours: hours
                  ) else { continue }
            cachedAvailability.append(interval)
        }

        presenter.friends = mapToFriends(cachedAvailability, members: cachedMembers, dateId: selectedDateId)
        presenter.bestTimeText = calculateBestTime(friends: presenter.friends)
    }
    func fetchMyCurrentHours() async -> [Int] {
        await fetchMyCurrentHours(for: presenter.selectedDateId)
    }

    func fetchMyCurrentHours(for dateId: String) async -> [Int] {
        let companyID = Int(company.id)
        let calendar = Calendar.current
        guard let selectedDate = Self.date(from: dateId) else { return [] }
        guard let existing = try? await userAvailabilityWorker.fetchMyAvailability(companyID: companyID) else { return [] }
        var hours: [Int] = []
        for interval in existing where calendar.isDate(interval.startTime, inSameDayAs: selectedDate) {
            let start = calendar.component(.hour, from: interval.startTime)
            let end   = calendar.component(.hour, from: interval.endTime)
            hours += Array(start...end)
        }
        return Array(Set(hours)).sorted()
    }

    func fetchMyCurrentWeekHours(for dateId: String) async -> [String: [Int]] {
        let companyID = Int(company.id)
        guard let selectedDate = Self.date(from: dateId) else { return [:] }
        let existing: [UserAvailability]
        if let userID = currentUserID {
            let cached = cachedAvailability.filter { $0.userID == userID }
            existing = cached.isEmpty ? ((try? await userAvailabilityWorker.fetchMyAvailability(companyID: companyID)) ?? []) : cached
        } else {
            existing = (try? await userAvailabilityWorker.fetchMyAvailability(companyID: companyID)) ?? []
        }

        let calendar = Calendar(identifier: .gregorian)
        let weekStart = Self.startOfWeekMonday(for: selectedDate)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return [:] }

        var hoursByDate: [String: Set<Int>] = [:]

        for interval in existing where interval.startTime >= weekStart && interval.startTime < weekEnd {
            let dateId = Self.dateId(from: interval.startTime)
            let startHour = calendar.component(.hour, from: interval.startTime)
            let endHour = calendar.component(.hour, from: interval.endTime)
            var set = hoursByDate[dateId] ?? []
            for hour in startHour...endHour {
                set.insert(hour)
            }
            hoursByDate[dateId] = set
        }

        return hoursByDate.mapValues { Array($0).sorted() }
    }

    func selectDate(dateId: String) {
        presenter.selectedDateId = dateId
        presenter.friends = mapToFriends(cachedAvailability, members: cachedMembers, dateId: dateId)

        // dateId format is "yyyy-MM-dd"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let selectedDate = formatter.date(from: dateId)
        let isToday = selectedDate.map { Calendar.current.isDateInToday($0) } ?? false

        presenter.bestTimeText = calculateBestTime(friends: presenter.friends)

        Task {
            do {
                let events = try await meetingsWorker.fetchCompanyEvents(companyId: Int(company.id))
                let calendar = Calendar.current

                let filtered = events.filter { event in
                    guard let startTime = event.startTime,
                          let selectedDate = selectedDate else { return false }
                    let iso = ISO8601DateFormatter()
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    var date = iso.date(from: startTime)
                    if date == nil {
                        let basic = ISO8601DateFormatter()
                        basic.formatOptions = [.withInternetDateTime]
                        date = basic.date(from: startTime)
                    }
                    guard let parsed = date else { return false }
                    return calendar.isDate(parsed, inSameDayAs: selectedDate)
                }

                let meetings = filtered.map { event in
                    MainScreen.Meeting(
                        timeText: formatTime(from: event.startTime),
                        title: event.title,
                        locationText: event.description ?? ""
                    )
                }

                await MainActor.run {
                    presenter.meetings = meetings
                }
            } catch {
                print("Failed to fetch meetings for date: \(error)")
                await MainActor.run {
                    presenter.meetings = []
                }
            }
        }
    }
    func updateMyFreeHours(_ hours: [Int]) {
        updateMyFreeHours(hours, for: presenter.selectedDateId)
    }

    func updateMyFreeHours(_ hours: [Int], for dateId: String) {
        applyOptimisticAvailabilityForDay(hours: hours, dateId: dateId)

        Task {
            do {
                let companyID = Int(company.id)
                let calendar = Calendar.current
                guard let selectedDate = Self.date(from: dateId) else { return }

                // 1) Fetch existing intervals for current user
                let existing = try await userAvailabilityWorker.fetchMyAvailability(companyID: companyID)

                // 2) Delete intervals only for the selected day
                let intervalsForSelectedDay = existing.filter {
                    calendar.isDate($0.startTime, inSameDayAs: selectedDate)
                }

                for interval in intervalsForSelectedDay {
                    try await userAvailabilityWorker.deleteAvailability(
                        companyID: companyID,
                        availabilityID: interval.id
                    )
                }

                // 3) If new hours is empty, just refresh the selected day state after deletion
                guard !hours.isEmpty else {
                    let availability = try await availabilityWorker.fetchCompanyAvailability(companyID: companyID)
                    let members = try await membersWorker.fetchMembers(companyID: companyID)
                    self.cachedAvailability = availability
                    self.cachedMembers = members
                    let friends = self.mapToFriends(availability, members: members, dateId: dateId)

                    await MainActor.run {
                        presenter.friends = friends
                        presenter.bestTimeText = self.calculateBestTime(friends: friends)
                    }
                    return
                }

                // 4) Post new interval
                var startComps = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                var endComps   = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                startComps.hour   = hours.min()
                startComps.minute = 0
                startComps.second = 0
                endComps.hour     = hours.max()
                endComps.minute   = 0
                endComps.second   = 0

                guard let startTime = calendar.date(from: startComps),
                      let endTime   = calendar.date(from: endComps) else { return }

                // Debug
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone.current
                print("Sending start_time: \(formatter.string(from: startTime))")
                print("Sending end_time: \(formatter.string(from: endTime))")

                try await userAvailabilityWorker.createAvailability(
                    companyID: companyID,
                    startTime: startTime,
                    endTime: endTime
                )

                // 5) Reload timetable from backend so UI reflects real data
                let availability = try await availabilityWorker.fetchCompanyAvailability(companyID: companyID)
                let members = try await membersWorker.fetchMembers(companyID: companyID)
                self.cachedAvailability = availability
                self.cachedMembers = members
                let friends = self.mapToFriends(availability, members: members, dateId: dateId)

                await MainActor.run {
                    presenter.friends = friends
                    presenter.bestTimeText = self.calculateBestTime(friends: friends)
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.availabilityUpdated,
                        parameters: [
                            "screen": "MainScreen",
                            "company_id": companyID,
                            "selected_hours_count": hours.count,
                            "selected_hours_min": hours.min(),
                            "selected_hours_max": hours.max()
                        ]
                    )
                }

            } catch {
                print("Failed to update availability: \(error)")
            }
        }
    }

    func updateMyFreeHours(forWeek hoursByDate: [String: [Int]], selectedDateId: String) {
        applyOptimisticAvailabilityForWeek(hoursByDate: hoursByDate, selectedDateId: selectedDateId)

        Task {
            do {
                let companyID = Int(company.id)
                let calendar = Calendar.current
                guard let selectedDate = Self.date(from: selectedDateId) else { return }
                let weekStart = Self.startOfWeekMonday(for: selectedDate)
                guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }

                let existing = try await userAvailabilityWorker.fetchMyAvailability(companyID: companyID)
                let intervalsForSelectedWeek = existing.filter {
                    $0.startTime >= weekStart && $0.startTime < weekEnd
                }

                for interval in intervalsForSelectedWeek {
                    try await userAvailabilityWorker.deleteAvailability(
                        companyID: companyID,
                        availabilityID: interval.id
                    )
                }

                for (dateId, hours) in hoursByDate {
                    guard !hours.isEmpty, let dayDate = Self.date(from: dateId) else { continue }

                    var startComps = calendar.dateComponents([.year, .month, .day], from: dayDate)
                    var endComps = calendar.dateComponents([.year, .month, .day], from: dayDate)
                    startComps.hour = hours.min()
                    startComps.minute = 0
                    startComps.second = 0
                    endComps.hour = hours.max()
                    endComps.minute = 0
                    endComps.second = 0

                    guard
                        let startTime = calendar.date(from: startComps),
                        let endTime = calendar.date(from: endComps)
                    else { continue }

                    try await userAvailabilityWorker.createAvailability(
                        companyID: companyID,
                        startTime: startTime,
                        endTime: endTime
                    )
                }

                let availability = try await availabilityWorker.fetchCompanyAvailability(companyID: companyID)
                let members = try await membersWorker.fetchMembers(companyID: companyID)
                self.cachedAvailability = availability
                self.cachedMembers = members
                let friends = self.mapToFriends(availability, members: members, dateId: selectedDateId)

                await MainActor.run {
                    self.presenter.friends = friends
                    self.presenter.bestTimeText = self.calculateBestTime(friends: friends)
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.availabilityUpdated,
                        parameters: [
                            "screen": "MainScreen",
                            "company_id": companyID,
                            "days_updated_count": hoursByDate.filter { !$0.value.isEmpty }.count
                        ]
                    )
                }
            } catch {
                print("Failed to update weekly availability: \(error)")
            }
        }
    }

    private static func date(from dateId: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateId)
    }

    private static func dateId(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func startOfWeekMonday(for date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }
    private func generateDatesForThreeMonths() -> [MainScreen.DateItem] {
        let calendar = Calendar.current
        let now = Date()

        let startOfMonthComponents = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: startOfMonthComponents) else { return [] }

        guard
            let threeMonthsAhead = calendar.date(byAdding: DateComponents(month: 3), to: startOfMonth),
            let endDate = calendar.date(byAdding: DateComponents(day: -1), to: threeMonthsAhead)
        else { return [] }

        let ruShortWeekdays = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

        var result: [MainScreen.DateItem] = []
        var date = startOfMonth

        let idFormatter = DateFormatter()
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.dateFormat = "yyyy-MM-dd"

        while date <= endDate {
            let weekdayIndex = calendar.component(.weekday, from: date)
            let weekdayShort = ruShortWeekdays[(weekdayIndex - 1) % 7]
            let dayNumber = String(calendar.component(.day, from: date))
            let id = idFormatter.string(from: date)
            let isToday = calendar.isDateInToday(date)

            result.append(
                .init(
                    id: id,
                    weekdayShort: weekdayShort,
                    dayNumber: dayNumber,
                    isToday: isToday
                )
            )

            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        return result
    }
    private func calculateBestTime(friends: [MainScreen.Friend]) -> String {
        guard !friends.isEmpty else { return "Нет данных" }
        
        // Count how many friends are free at each hour
        var hourCounts: [Int: Int] = [:]
        for hour in 0...23 {
            let count = friends.filter { $0.freeHours.contains(hour) }.count
            if count > 0 {
                hourCounts[hour] = count
            }
        }
        
        guard !hourCounts.isEmpty else { return "Нет свободного времени" }
        
        // Find the maximum overlap count
        let maxCount = hourCounts.values.max() ?? 0
        
        // Get all hours with that max count, sorted
        let bestHours = hourCounts
            .filter { $0.value == maxCount }
            .map { $0.key }
            .sorted()
        
        guard !bestHours.isEmpty else { return "Нет свободного времени" }
        
        // Group consecutive hours into ranges
        var ranges: [(start: Int, end: Int)] = []
        var rangeStart = bestHours[0]
        var rangeEnd = bestHours[0]
        
        for i in 1..<bestHours.count {
            if bestHours[i] == rangeEnd + 1 {
                rangeEnd = bestHours[i]
            } else {
                ranges.append((rangeStart, rangeEnd))
                rangeStart = bestHours[i]
                rangeEnd = bestHours[i]
            }
        }
        ranges.append((rangeStart, rangeEnd))
        
        // Pick the longest range
        let best = ranges.max(by: { ($0.end - $0.start) < ($1.end - $1.start) })!
        
        let totalFriends = friends.count
        let countText = maxCount == totalFriends
            ? "могут все"
            : "\(maxCount) из \(totalFriends)"
        
        return String(format: "%02d:00–%02d:00 — %@", best.start, best.end, countText)
    }
}
extension Notification.Name {
    static let meetingDeleted = Notification.Name("meetingDeleted")
}
