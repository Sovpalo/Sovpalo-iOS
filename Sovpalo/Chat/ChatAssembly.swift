import UIKit

enum ChatAssembly {
    static func assembly(company: Company) -> UIViewController {
        let vc = ChatViewController()
        vc.groupName = company.name
        let interactor = ChatInteractor(company: company)
        let presenter = ChatPresenter()
        let worker = ChatWorker()

        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc

        return vc
    }
}
