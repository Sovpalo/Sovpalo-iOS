//
//  AvatarRegisterWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 22.04.2026.
//

import Foundation

protocol AvatarRegisterWorkerProtocol {
    func uploadAvatar(imageData: Data, fileName: String, mimeType: String) async throws
}

enum AvatarRegisterWorkerError: LocalizedError {
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
        case let .badStatus(_, message):
            return extractReadableMessage(from: message)
        }
    }

    private func extractReadableMessage(from rawMessage: String) -> String {
        if let data = rawMessage.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = jsonObject["message"] as? String,
           !message.isEmpty {
            return message
        }

        return rawMessage.isEmpty ? "Не удалось загрузить фото" : rawMessage
    }
}

final class AvatarRegisterWorker: AvatarRegisterWorkerProtocol {
    private let network: any NetworkServicing

    init(
        keychain: KeychainLogic = KeychainService(),
        session: URLSession = .shared,
        network: (any NetworkServicing)? = nil
    ) {
        self.network = network ?? NetworkService(session: session, keychain: keychain)
    }

    func uploadAvatar(imageData: Data, fileName: String, mimeType: String) async throws {
        print("[AvatarRegisterWorker] Upload payload info: fileName=\(fileName), mimeType=\(mimeType), size=\(imageData.count) bytes")

        let file = MultipartFormFile(
            fieldName: "avatar",
            fileName: fileName,
            mimeType: mimeType,
            data: imageData
        )

        _ = try await network.multipartData(
            path: "auth/me/avatar",
            method: .post,
            authorized: true,
            fields: [:],
            files: [file],
            headers: [:]
        )
    }
}
