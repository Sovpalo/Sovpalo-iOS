final class MainScreenInteractor {
    private let presenter: MainScreenPresenter

    init(presenter: MainScreenPresenter) {
        self.presenter = presenter
    }

    func load() {
        // Mock data
        presenter.dates = [
            .init(id: "2026-01-24", weekdayShort: "Пн", dayNumber: "24", isToday: false),
            .init(id: "2026-01-25", weekdayShort: "Вт", dayNumber: "25", isToday: true),
            .init(id: "2026-01-26", weekdayShort: "Ср", dayNumber: "26", isToday: false),
            .init(id: "2026-01-27", weekdayShort: "Чт", dayNumber: "27", isToday: false),
            .init(id: "2026-01-28", weekdayShort: "Пт", dayNumber: "28", isToday: false),
            .init(id: "2026-01-29", weekdayShort: "Сб", dayNumber: "29", isToday: false),
            .init(id: "2026-01-30", weekdayShort: "Вс", dayNumber: "30", isToday: false)
        ]
        presenter.selectedDateId = "2026-01-25"
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
}
