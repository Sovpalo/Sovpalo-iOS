//
//  MyGroupInteractor.swift
//  Sovpalo
//
//  Created by Jovana on 24.3.26.
//

//  GroupMembersInteractor.swift
//  Sovpalo

import Foundation

protocol GroupMembersBusinessLogic: AnyObject {
    func loadMembers()
}

final class GroupMembersInteractor: GroupMembersBusinessLogic {
    var presenter: GroupMembersPresenterProtocol?
    var worker: CompanyMembersWorkerProtocol

    private let company: Company

    init(company: Company, worker: CompanyMembersWorkerProtocol = CompanyMembersWorker()) {
        self.company = company
        self.worker = worker
    }

    func loadMembers() {
        Task {
            do {
                let members = try await worker.fetchMembers(companyID: Int(company.id))
                await MainActor.run {
                    presenter?.presentMembers(members)
                }
            } catch {
                await MainActor.run {
                    presenter?.presentError(error)
                }
            }
        }
    }
}
