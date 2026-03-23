import Foundation

final class MainScreenInteractor {
    private let company: Company
    private let presenter: MainScreenPresenter
    private let availabilityWorker: GroupAvailabilityWorkerProtocol
    private let membersWorker: CompanyMembersWorkerProtocol
    private let userAvailabilityWorker: UserAvailabilityWorkerProtocol

    init(
        company: Company,
        presenter: MainScreenPresenter,
        availabilityWorker: GroupAvailabilityWorkerProtocol = GroupAvailabilityWorker(),
        membersWorker: CompanyMembersWorkerProtocol = CompanyMembersWorker(),
        userAvailabilityWorker: UserAvailabilityWorkerProtocol = UserAvailabilityWorker()
    ) {
        self.company = company
        self.presenter = presenter
        self.availabilityWorker = availabilityWorker
        self.membersWorker = membersWorker
        self.userAvailabilityWorker = userAvailabilityWorker
    }

    func load() {
        print("Loading MainScreen for company id: \(company.id), name: \(company.name)")

        presenter.dates = generateDatesForThreeMonths()

        if let today = presenter.dates.first(where: { $0.isToday }) {
            presenter.selectedDateId = today.id
        } else {
            presenter.selectedDateId = presenter.dates.first?.id ?? ""
        }

        presenter.todayTitle = "Встречи сегодня"
        presenter.meetings = [
            MainScreen.Meeting(
                timeText: "14:00",
                title: "Скаладром ЦСКА",
                locationText: "Москва, 3-я песчаная улица 2с1"
            )
        ]
        presenter.bestTimeText = "14:00–17:00 — можете все"

        Task {
                  do {
                      // Fire both requests in parallel
                      async let availabilityItems = availabilityWorker.fetchCompanyAvailability(companyID: Int(company.id))
                      async let memberItems = membersWorker.fetchMembers(companyID: Int(company.id))

                      let (availability, members) = try await (availabilityItems, memberItems)
                      let friends = mapToFriends(availability, members: members)

                      await MainActor.run {
                          presenter.friends = friends
                      }
                  } catch {
                      print("Failed to fetch friends data: \(error)")
                      await MainActor.run {
                          presenter.friends = demoFriends()
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

        let isToday = presenter.dates.first(where: { $0.id == dateId })?.isToday ?? false

        presenter.meetings = isToday
            ? [
                MainScreen.Meeting(
                    timeText: "14:00",
                    title: "Скаладром ЦСКА",
                    locationText: "Москва, 3-я песчаная улица 2с1"
                )
            ]
            : []

        presenter.bestTimeText = "14:00–17:00 — можете все"
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
}

