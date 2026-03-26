//
//  IdeasListInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import Foundation

protocol IdeasListBusinessLogic {
    func loadIdeas()
    func toggleLike(ideaId: Int)
    func openCreateIdea()
}

final class IdeasListInteractor: IdeasListBusinessLogic {
    let company: Company

    var presenter: IdeasListPresenterProtocol?
    var worker: IdeasListWorkerProtocol?

    private var ideas: [CompanyIdea] = []

    init(company: Company) {
        self.company = company
    }

    func loadIdeas() {
        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        Task {
            do {
                let dto = try await worker.fetchIdeas(companyId: company.id)
                let ideas = dto
                    .map(mapIdea)
                    .sorted { lhs, rhs in
                        lhs.id > rhs.id
                    }

                self.ideas = ideas
                presenter?.presentIdeas(ideas)
            } catch {
                presenter?.presentError(error.localizedDescription)
            }
        }
    }

    func toggleLike(ideaId: Int) {
        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else {
            return
        }

        let idea = ideas[index]

        Task {
            do {
                if idea.isLiked {
                    try await worker.unlikeIdea(companyId: company.id, ideaId: ideaId)
                } else {
                    try await worker.likeIdea(companyId: company.id, ideaId: ideaId)
                }

                var updatedIdea = idea
                updatedIdea.isLiked.toggle()
                updatedIdea.likesCount = max(0, updatedIdea.likesCount + (updatedIdea.isLiked ? 1 : -1))
                self.ideas[index] = updatedIdea

                presenter?.presentIdeaLikeUpdated(updatedIdea)
            } catch {
                presenter?.presentError(error.localizedDescription)
            }
        }
    }

    func openCreateIdea() {
        presenter?.routeToCreateIdea(company: company)
    }

    private func mapIdea(dto: CompanyIdeaDTO) -> CompanyIdea {
        CompanyIdea(
            id: dto.id,
            title: dto.title,
            authorName: dto.authorName,
            descriptionText: dto.description,
            likesCount: dto.likesCount,
            isLiked: dto.isLiked
        )
    }
}

struct CompanyIdea {
    let id: Int
    let title: String
    let authorName: String
    let descriptionText: String?
    var likesCount: Int
    var isLiked: Bool
}
