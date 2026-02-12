//
//  CreateGroupInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import Foundation

protocol CreateGroupBusinessLogic {
    /// Создаёт компанию и сообщает результат презентеру
    /// - Parameters:
    ///   - name: Название компании
    ///   - description: Описание компании (опционально)
    func createCompany(name: String, description: String?)
}

final class CreateGroupInteractor: CreateGroupBusinessLogic {
    var presenter: CreateGroupPresenterProtocol?
    var worker: CreateGroupWorkerProtocol?
    
    func createCompany(name: String, description: String?) {
        guard let worker else {
            Task { @MainActor [weak self] in
                self?.presenter?.presentCreateCompanyError("Worker is unavailable")
            }
            return
        }

        Task { [weak self] in
            do {
                let companyId = try await worker.createCompany(name: name, description: description)
                await MainActor.run { [weak self] in
                    self?.presenter?.presentCreateCompanySuccess(companyId: companyId)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.presenter?.presentCreateCompanyError(error.localizedDescription)
                }
            }
        }
    }
}
