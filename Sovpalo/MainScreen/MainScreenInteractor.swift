import Foundation

final class MainScreenInteractor {
    private let presenter: MainScreenPresenter

    init(presenter: MainScreenPresenter) {
        self.presenter = presenter
    }

    func load() {
        presenter.dates = generateDatesForThreeMonths()
        if let today = presenter.dates.first(where: { $0.isToday }) {
            presenter.selectedDateId = today.id
        } else {
            presenter.selectedDateId = presenter.dates.first?.id ?? ""
        }
        presenter.todayTitle = "Встречи сегодня"
        presenter.meetings = [
            MainScreen.Meeting(timeText: "14:00", title: "Скаладром ЦСКА", locationText: "Москва, 3-я песчаная улица 2с1")
        ]
        presenter.bestTimeText = "14:00–17:00 — можете все"
        presenter.friends = [
            MainScreen.Friend(id: "me", name: "Я", avatarLetter: "Я", isMe: true),
            MainScreen.Friend(id: "alena", name: "Миа", avatarLetter: "М", isMe: false),
            MainScreen.Friend(id: "vanya", name: "Теа", avatarLetter: "Т", isMe: false),
            MainScreen.Friend(id: "pasha", name: "Ана", avatarLetter: "А", isMe: false)
        ]
        presenter.hours = ["09", "10", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21"]
    }

    func selectDate(dateId: String) {
        presenter.selectedDateId = dateId
        // Update meetings for selected date if needed
        presenter.meetings = presenter.dates.first(where: { $0.id == dateId })?.isToday ?? false ?
        [ MainScreen.Meeting(timeText: "14:00", title: "Скаладром ЦСКА", locationText: "Москва, 3-я песчаная улица 2с1")] : []
        presenter.bestTimeText = "14:00–17:00 — можете все"
    }

    private func generateDatesForThreeMonths() -> [MainScreen.DateItem] {
        let calendar = Calendar.current
        let now = Date()

        // Start: first day of the current month
        let startOfMonthComponents = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: startOfMonthComponents) else { return [] }

        // End: last day of the month two months ahead (total ~3 months)
        guard
            let threeMonthsAhead = calendar.date(byAdding: DateComponents(month: 3), to: startOfMonth),
            let endDate = calendar.date(byAdding: DateComponents(day: -1), to: threeMonthsAhead)
        else { return [] }

        // Russian short weekday symbols mapping (Calendar weekday: 1=Sunday ... 7=Saturday)
        let ruShortWeekdays = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

        var result: [MainScreen.DateItem] = []
        var date = startOfMonth

        // Stable ID formatter
        let idFormatter = DateFormatter()
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.dateFormat = "yyyy-MM-dd"

        while date <= endDate {
            let weekdayIndex = calendar.component(.weekday, from: date) // 1...7
            let weekdayShort = ruShortWeekdays[(weekdayIndex - 1) % 7]
            let dayNumber = String(calendar.component(.day, from: date))
            let id = idFormatter.string(from: date)
            let isToday = calendar.isDateInToday(date)

            result.append(.init(id: id, weekdayShort: weekdayShort, dayNumber: dayNumber, isToday: isToday))

            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        return result
    }
}
