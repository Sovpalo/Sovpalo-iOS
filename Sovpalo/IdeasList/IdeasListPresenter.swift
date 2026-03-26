//
//  IdeasListPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

protocol IdeasListPresenterProtocol: AnyObject {
    func presentIdeas(_ ideas: [CompanyIdea])
    func presentIdeaLikeUpdated(_ idea: CompanyIdea)
    func presentError(_ message: String)
    func routeToCreateIdea(company: Company)
}

final class IdeasListPresenter: IdeasListPresenterProtocol {
    weak var vc: IdeasListVC?

    func presentIdeas(_ ideas: [CompanyIdea]) {
        let viewModels = ideas.map { makeViewModel(from: $0) }
        DispatchQueue.main.async { [weak vc] in
            vc?.applyIdeas(viewModels)
        }
    }

    func presentIdeaLikeUpdated(_ idea: CompanyIdea) {
        let viewModel = makeViewModel(from: idea)
        DispatchQueue.main.async { [weak vc] in
            vc?.applyLikeUpdate(viewModel)
        }
    }

    func presentError(_ message: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.showError(message: message)
        }
    }

    func routeToCreateIdea(company: Company) {
        DispatchQueue.main.async { [weak vc] in
            let createIdeasVC = CreateIdeasAssembly.assembly(company: company)
            vc?.navigationController?.pushViewController(createIdeasVC, animated: true)
        }
    }

    private func makeViewModel(from idea: CompanyIdea) -> IdeaCardViewModel {
        let trimmedDescription = idea.descriptionText?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return IdeaCardViewModel(
            id: idea.id,
            title: idea.title,
            authorName: idea.authorName,
            descriptionText: trimmedDescription,
            likesText: "\(idea.likesCount)",
            likesCount: idea.likesCount,
            isLiked: idea.isLiked
        )
    }
}

struct IdeaCardViewModel {
    let id: Int
    let title: String
    let authorName: String
    let descriptionText: String?
    let likesText: String
    let likesCount: Int
    let isLiked: Bool
}
