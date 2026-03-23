import UIKit

final class MeetingsAssembly {
    static func assembly(company: Company) -> MeetingsVC {
        let vc = MeetingsVC()
        let interactor = MeetingsInteractor(company: company)
        let presenter = MeetingsPresenter()
        let worker = MeetingsWorker()

        vc.company = company
        vc.companyTitle = company.name

        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc

        return vc
    }
}
