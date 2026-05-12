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
    func leaveCompany()
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
            let cachedMembers = LocalCacheService.shared.fetchMembers(companyId: company.id)
            let currentUserID = Self.currentUserID()
            let didShowCachedMembers = !cachedMembers.isEmpty

            if didShowCachedMembers {
                await MainActor.run {
                    presenter?.presentOfflineMode(true)
                    presenter?.presentMembers(cachedMembers, currentUserID: currentUserID)
                }
            }

            do {
                let members = try await worker.fetchMembers(companyID: Int(company.id))
                LocalCacheService.shared.saveMembers(members, companyId: company.id)
                await MainActor.run {
                    presenter?.presentOfflineMode(false)
                    presenter?.presentMembers(members, currentUserID: currentUserID)
                }
            } catch {
                await MainActor.run {
                    if didShowCachedMembers {
                        presenter?.presentOfflineMode(true)
                    } else {
                        presenter?.presentOfflineMode(false)
                        presenter?.presentError(error)
                    }
                }
            }
        }
    }

    func removeMember(userID: Int) {
        Task {
            do {
                try await worker.removeMember(companyID: Int(company.id), userID: userID)
                let members = try await worker.fetchMembers(companyID: Int(company.id))
                LocalCacheService.shared.saveMembers(members, companyId: company.id)
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

    func leaveCompany() {
        Task {
            await MainActor.run {
                presenter?.presentLeaveCompanyLoading(true)
            }

            do {
                try await worker.leaveCompany(companyID: Int(company.id))
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.companyMemberRemoved,
                        parameters: [
                            "screen": "GroupMembers",
                            "company_id": Int(self.company.id),
                            "removed_user_id": Self.currentUserID() ?? -1,
                            "self_leave": true
                        ]
                    )
                    self.presenter?.presentLeaveCompanyLoading(false)
                    self.presenter?.presentLeaveCompanySuccess()
                }
            } catch {
                await MainActor.run {
                    self.presenter?.presentLeaveCompanyLoading(false)
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
