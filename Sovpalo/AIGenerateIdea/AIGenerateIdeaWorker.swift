//
//  AIGenerateIdeaWorker.swift
//  Sovpalo
//

import Foundation

struct IdeaGeneratePayload: Encodable {
    let topic: String
    let count: Int
}

struct IdeaGenerateResponseDTO: Decodable {
    let items: [GeneratedIdeaDraftDTO]
}

struct GeneratedIdeaDraftDTO: Decodable {
    let title: String
    let description: String
    let source: String
    let llmPrompt: String

    enum CodingKeys: String, CodingKey {
        case title, description, source
        case llmPrompt = "llm_prompt"
    }
}

enum AIGenerateIdeaWorkerError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case badServerResponse
    case badStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL запроса"
        case .tokenNotFound:
            return "Не найден токен авторизации"
        case .tokenDecodingFailed:
            return "Не удалось прочитать токен авторизации"
        case .badServerResponse:
            return "Некорректный ответ сервера"
        case let .badStatus(code, message):
            return humanReadableServerError(code: code, raw: message)
        }
    }
}

private func humanReadableServerError(code: Int, raw: String) -> String {
    if let data = raw.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let msg = json["message"] as? String, !msg.isEmpty { return msg }
        if let err = json["error"] as? String, !err.isEmpty { return err }
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, trimmed.count < 400 { return trimmed }
    return "Ошибка сервера (\(code))"
}

protocol AIGenerateIdeaWorkerProtocol {
    func generateIdeas(companyId: Int, topic: String, count: Int) async throws -> [GeneratedIdeaDraftDTO]
}

final class AIGenerateIdeaWorker: AIGenerateIdeaWorkerProtocol {
    private let keychain: KeychainLogic
    private let baseURL: String = Server.url

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func generateIdeas(companyId: Int, topic: String, count: Int) async throws -> [GeneratedIdeaDraftDTO] {
        guard let url = URL(string: baseURL + "/companies/\(companyId)/ideas/generate") else {
            throw AIGenerateIdeaWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw AIGenerateIdeaWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw AIGenerateIdeaWorkerError.tokenDecodingFailed
        }

        let payload = IdeaGeneratePayload(topic: topic, count: count)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIGenerateIdeaWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw AIGenerateIdeaWorkerError.badStatus(code: httpResponse.statusCode, message: serverMessage)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(IdeaGenerateResponseDTO.self, from: data)
        return decoded.items
    }
}
