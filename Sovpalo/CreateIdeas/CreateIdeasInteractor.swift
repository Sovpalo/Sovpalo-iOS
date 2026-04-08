//
//  CreateIdeasInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import Foundation

protocol CreateIdeasBusinessLogic {
    func createIdea(request: CreateIdeaRequest)
}

final class CreateIdeasInteractor: CreateIdeasBusinessLogic {
    private let company: Company

    var presenter: CreateIdeasPresenterProtocol?
    var worker: CreateIdeasWorkerProtocol?

    init(company: Company) {
        self.company = company
    }

    func createIdea(request: CreateIdeaRequest) {
        guard let worker else {
            presenter?.presentError(message: "Worker is unavailable")
            return
        }

        let trimmedTitle = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            presenter?.presentError(message: "Введите название идеи")
            return
        }

        let trimmedDescription = request.description.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = CreateIdeaPayload(
            title: trimmedTitle,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription
        )

        Task {
            do {
                try await worker.createIdea(companyId: company.id, payload: payload)
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.ideaCreated,
                        parameters: [
                            "screen": "CreateIdeas",
                            "company_id": self.company.id,
                            "has_description": !trimmedDescription.isEmpty
                        ]
                    )
                    self.presenter?.presentSuccess()
                }
            } catch {
                await MainActor.run {
                    self.presenter?.presentError(message: error.localizedDescription)
                }
            }
        }
    }
}

struct CreateIdeaRequest {
    let title: String
    let description: String
}
