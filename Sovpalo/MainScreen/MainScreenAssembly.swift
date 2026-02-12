import SwiftUI

enum MainScreenAssembly {
    static func build() -> some View {
        let presenter = MainScreenPresenter()
        let interactor = MainScreenInteractor(presenter: presenter)
        return MainScreenView(presenter: presenter, interactor: interactor)
    }
}
