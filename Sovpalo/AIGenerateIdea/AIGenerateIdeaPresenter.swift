//
//  AIGenerateIdeaPresenter.swift
//  Sovpalo
//

import UIKit

protocol AIGenerateIdeaPresenterProtocol: AnyObject {
    func presentLoadingStarted()
    func presentDrafts(_ drafts: [AIGeneratedDraftViewModel])
    func presentError(message: String)
    func routeToPublishDraft(_ draft: AIGeneratedDraftViewModel, company: Company)
}

final class AIGenerateIdeaPresenter: AIGenerateIdeaPresenterProtocol {
    weak var vc: AIGenerateIdeaVC?
    private let company: Company

    init(company: Company) {
        self.company = company
    }

    func presentLoadingStarted() {
        DispatchQueue.main.async { [weak vc] in
            vc?.setLoading(true)
        }
    }

    func presentDrafts(_ drafts: [AIGeneratedDraftViewModel]) {
        DispatchQueue.main.async { [weak vc] in
            vc?.setLoading(false)
            vc?.applyDrafts(drafts)
        }
    }

    func presentError(message: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.setLoading(false)
            vc?.showError(message: message)
        }
    }

    func routeToPublishDraft(_ draft: AIGeneratedDraftViewModel, company: Company) {
        DispatchQueue.main.async { [weak vc] in
            let prefill = CreateIdeaRequest(title: draft.title, description: draft.description)
            let createVC = CreateIdeasAssembly.assembly(company: company, prefill: prefill)
            vc?.navigationController?.pushViewController(createVC, animated: true)
        }
    }
}
