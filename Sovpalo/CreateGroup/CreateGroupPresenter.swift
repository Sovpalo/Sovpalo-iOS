//
//  CreateGroupPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import UIKit

protocol CreateGroupPresenterProtocol: AnyObject {
    func presentCreateCompanySuccess(companyId: Int)
    func presentCreateCompanyError(_ message: String)
}

final class CreateGroupPresenter: CreateGroupPresenterProtocol {
    weak var vc: CreateGroupVC?
    
    func presentCreateCompanySuccess(companyId: Int) {
        guard let navigationController = vc?.navigationController else { return }
        let inviteVC = InviteUserAssembly.assembly(companyId: companyId)
        inviteVC.onDone = {
            // pop back to GroupListViewController
            if let groupListVC = navigationController.viewControllers.first(where: { $0 is GroupListViewController }) {
                navigationController.popToViewController(groupListVC, animated: true)
            } else {
                navigationController.popToRootViewController(animated: true)
            }
        }
        navigationController.pushViewController(inviteVC, animated: true)
    }

    func presentCreateCompanyError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc?.present(alert, animated: true)
    }
}
