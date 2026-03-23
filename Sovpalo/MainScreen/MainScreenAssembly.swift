import SwiftUI

enum MainScreenAssembly {
    static func build(company: Company) -> some View {
        let presenter = MainScreenPresenter(company: company)
        let interactor = MainScreenInteractor(
            company: company,
            presenter: presenter
        )
        return MainScreenView(presenter: presenter, interactor: interactor)
    }
}
