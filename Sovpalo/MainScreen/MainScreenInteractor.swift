import Foundation

final class MainScreenInteractor {
    private let company: Company
    private let presenter: MainScreenPresenter
    private let availabilityWorker: GroupAvailabilityWorkerProtocol
    private let membersWorker: CompanyMembersWorkerProtocol
    private let userAvailabilityWorker: UserAvailabilityWorkerProtocol
    private let meetingsWorker: MeetingsWorkerProtocol

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
                let friends = mapToFriends(availability, members: members)

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
    
    private func mapToFriends(_ items: [UserAvailability], members: [CompanyMemberView]) -> [MainScreen.Friend] {
       var currentUserID: Int {
            guard let data = KeychainService().getData(forKey: "auth.userId"),
                  let str = String(data: data, encoding: .utf8),
                  let id = Int(str) else { return -1 }
            return id
        }
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: items, by: \.userID)

            // Build a lookup of userID -> member so we can get username
            let membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.userID, $0) })

            return members.map { member in
                let intervals = grouped[member.userID] ?? []
                var freeHours: [Int] = []
                for interval in intervals {
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
    func fetchMyCurrentHours() async -> [Int] {
        let companyID = Int(company.id)
        let calendar = Calendar.current
        guard let existing = try? await userAvailabilityWorker.fetchMyAvailability(companyID: companyID) else { return [] }
        var hours: [Int] = []
        for interval in existing {
            let start = calendar.component(.hour, from: interval.startTime)
            let end   = calendar.component(.hour, from: interval.endTime)
            hours += Array(start...end)
        }
        return hours.sorted()
    }

    func selectDate(dateId: String) {
        presenter.selectedDateId = dateId

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
        // Update UI immediately
        if let index = presenter.friends.firstIndex(where: { $0.isMe }) {
            presenter.friends[index].freeHours = hours.sorted()
        }

        Task {
            do {
                let companyID = Int(company.id)

                // 1) Fetch existing intervals for current user
                let existing = try await userAvailabilityWorker.fetchMyAvailability(companyID: companyID)

                // 2) Delete all existing ones
                for interval in existing {
                    try await userAvailabilityWorker.deleteAvailability(
                        companyID: companyID,
                        availabilityID: interval.id
                    )
                }

                // 3) If new hours is empty, we're done
                guard !hours.isEmpty else { return }

                // 4) Post new interval
                let calendar = Calendar.current
                let today = Date()
                var startComps = calendar.dateComponents([.year, .month, .day], from: today)
                var endComps   = calendar.dateComponents([.year, .month, .day], from: today)
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
                let friends = mapToFriends(availability, members: members)

                await MainActor.run {
                    presenter.friends = friends
                    presenter.bestTimeText = self.calculateBestTime(friends: friends)
                }

            } catch {
                print("Failed to update availability: \(error)")
            }
        }
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
