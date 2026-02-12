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
        vc?.navigationController?.setViewControllers([FirstGroupAssembly.assembly()], animated: true)
    }

    func presentCreateCompanyError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc?.present(alert, animated: true)
    }
}
