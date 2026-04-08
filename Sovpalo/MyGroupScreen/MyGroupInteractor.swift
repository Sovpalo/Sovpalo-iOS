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
    func removeMember(userID: Int)
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
                let currentUserID = Self.currentUserID()
                await MainActor.run {
                    presenter?.presentMembers(members, currentUserID: currentUserID)
                }
            } catch {
                await MainActor.run {
                    presenter?.presentError(error)
                }
            }
        }
    }

    func removeMember(userID: Int) {
        Task {
            do {
                try await worker.removeMember(companyID: Int(company.id), userID: userID)
                let members = try await worker.fetchMembers(companyID: Int(company.id))
                let currentUserID = Self.currentUserID()
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.companyMemberRemoved,
                        parameters: [
                            "screen": "GroupMembers",
                            "company_id": Int(self.company.id),
                            "removed_user_id": userID
                        ]
                    )
                    self.presenter?.presentMembers(members, currentUserID: currentUserID)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.presentError(error)
                }
            }
        }
    }

    private static func currentUserID() -> Int? {
        guard
            let data = KeychainService().getData(forKey: "auth.userId"),
            let string = String(data: data, encoding: .utf8),
            let userID = Int(string)
        else {
            return nil
        }

        return userID
    }
}
