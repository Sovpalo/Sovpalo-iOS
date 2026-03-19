import SwiftUI
import Combine

final class MainScreenPresenter: ObservableObject {
    let company: Company

    @Published var dates: [MainScreen.DateItem] = []
    @Published var selectedDateId: String = ""
    @Published var meetings: [MainScreen.Meeting] = []
    @Published var bestTimeText: String = ""
    @Published var friends: [MainScreen.Friend] = []
    @Published var hours: [String] = []
    @Published var todayTitle: String = ""

    init(company: Company) {
        self.company = company
    }
}
