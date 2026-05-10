//
//  AIGenerateIdeaInteractor.swift
//  Sovpalo
//

import Foundation

private let localDraftSource = "Local draft"

protocol AIGenerateIdeaBusinessLogic {
    func generateDrafts(topic: String)
    func publishDraft(_ draft: AIGeneratedDraftViewModel)
}

final class AIGenerateIdeaInteractor: AIGenerateIdeaBusinessLogic {
    private let company: Company

    var presenter: AIGenerateIdeaPresenterProtocol?
    var worker: AIGenerateIdeaWorkerProtocol?

    init(company: Company) {
        self.company = company
    }

    func generateDrafts(topic: String) {
        guard let worker else {
            presenter?.presentError(message: "Worker is unavailable")
            return
        }

        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presenter?.presentError(message: "Опишите запрос для генерации")
            return
        }

        presenter?.presentLoadingStarted()

        Task {
            do {
                let drafts = try await worker.generateIdeas(
                    companyId: company.id,
                    topic: trimmed,
                    count: 3
                )
                let models = drafts.map {
                    AIGeneratedDraftViewModel(
                        title: $0.title,
                        description: $0.description,
                        source: $0.source
                    )
                }
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.ideaDraftsGenerated,
                        parameters: [
                            "screen": "AIGenerateIdea",
                            "company_id": self.company.id,
                            "drafts_count": models.count
                        ]
                    )
                    self.presenter?.presentDrafts(models)
                }
            } catch {
                await MainActor.run {
                    if self.shouldOfferLocalDraftFallback(for: error) {
                        let fallbackDrafts = self.makeLocalFallbackDrafts(topic: trimmed)
                        self.presenter?.presentDrafts(fallbackDrafts)
                    } else {
                        self.presenter?.presentError(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    func publishDraft(_ draft: AIGeneratedDraftViewModel) {
        presenter?.routeToPublishDraft(draft, company: company)
    }

    /// Backend LLM path can fail for many reasons; show usable drafts so the screen is not blocked.
    private func shouldOfferLocalDraftFallback(for error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("idea generation service is temporarily unavailable")
            || message.contains("idea generation service is not configured")
            // Normalized in backend response.go when LLM call or parsing fails
            || message.contains("could not generate ideas right now")
            || message.contains("idea generation request failed")
            || message.contains("idea generation returned invalid")
    }

    private func makeLocalFallbackDrafts(topic: String) -> [AIGeneratedDraftViewModel] {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            AIGeneratedDraftViewModel(
                title: "\(cleanTopic): быстрый запуск MVP",
                description: "Собрать минимальную версию идеи для проверки спроса за 1-2 недели. Определить ключевую ценность, базовый сценарий и метрику успеха.",
                source: localDraftSource
            ),
            AIGeneratedDraftViewModel(
                title: "\(cleanTopic): комьюнити-формат",
                description: "Запустить формат с вовлечением участников: регулярные встречи, обмен результатами и публичный трек прогресса. Это повышает удержание и органический рост.",
                source: localDraftSource
            ),
            AIGeneratedDraftViewModel(
                title: "\(cleanTopic): партнерская интеграция",
                description: "Проверить идею через сотрудничество с релевантными партнерами. Пилот с ограниченной аудиторией поможет быстро собрать обратную связь и улучшить концепт.",
                source: localDraftSource
            )
        ]
    }
}

struct AIGeneratedDraftViewModel {
    let title: String
    let description: String
    let source: String
}
