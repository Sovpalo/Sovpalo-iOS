import Foundation

final class MainScreenInteractor {
    private let company: Company
    private let presenter: MainScreenPresenter

    init(company: Company, presenter: MainScreenPresenter) {
        self.company = company
        self.presenter = presenter
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
