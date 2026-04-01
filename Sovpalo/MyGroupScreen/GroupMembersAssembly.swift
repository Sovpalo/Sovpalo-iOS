//
//  GroupMembersAssembly.swift.swift
//  Sovpalo
//
//  Created by Jovana on 31.3.26.
//

//  GroupMembersAssembly.swift
//  Sovpalo

import UIKit

final class GroupMembersAssembly {
    static func build(company: Company) -> GroupMembersViewController {
        let view = GroupMembersViewController(company: company)
        let interactor = GroupMembersInteractor(company: company)
        let presenter = GroupMembersPresenter()

        view.interactor = interactor
        interactor.presenter = presenter
        presenter.view = view

        return view
    }
}
