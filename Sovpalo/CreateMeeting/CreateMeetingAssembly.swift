import UIKit

final class CreateMeetingAssembly {
    static func assembly(company: Company) -> CreateMeetingVC {
        let vc = CreateMeetingVC()
        let interactor = CreateMeetingInteractor(company: company)
        let presenter = CreateMeetingPresenter()
        let worker = CreateMeetingWorker()

        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc

        return vc
    }
}
