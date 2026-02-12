//
//  FirstGroupPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import UIKit

protocol FirstGroupPresenterProtocol {
    func presentCompanies(_ companies: [Company])
    func presentCompaniesError(_ message: String)
}

final class FirstGroupPresenter: FirstGroupPresenterProtocol {
    weak var vc: FirstGroupVC?

    func presentCompanies(_ companies: [Company]) {
        let names = companies.map { $0.name }
        DispatchQueue.main.async { [weak vc] in
            vc?.companies = names
        }
    }

    func presentCompaniesError(_ message: String) {
        DispatchQueue.main.async { [weak vc] in
            guard let viewController = vc else { return }
            let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
        }
    }
}
