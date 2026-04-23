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
    private let keychain: KeychainLogic
    private let session: URLSession

    init(
        keychain: KeychainLogic = KeychainService(),
        session: URLSession = .shared
    ) {
        self.keychain = keychain
        self.session = session
    }

    func uploadAvatar(imageData: Data, fileName: String, mimeType: String) async throws {
        guard let url = URL(string: Server.url + "/auth/me/avatar") else {
            throw AvatarRegisterWorkerError.invalidURL
        }

        print("[AvatarRegisterWorker] Preparing upload request to \(url.absoluteString)")

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            print("[AvatarRegisterWorker] Auth token not found in keychain")
            throw AvatarRegisterWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            print("[AvatarRegisterWorker] Failed to decode auth token from keychain data")
            throw AvatarRegisterWorkerError.tokenDecodingFailed
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        print("[AvatarRegisterWorker] Upload payload info: fileName=\(fileName), mimeType=\(mimeType), size=\(imageData.count) bytes")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[AvatarRegisterWorker] Server response is not HTTPURLResponse")
            throw AvatarRegisterWorkerError.badServerResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body, \(data.count) bytes>"
        print("[AvatarRegisterWorker] Response status: \(httpResponse.statusCode)")
        print("[AvatarRegisterWorker] Response body: \(responseBody)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка сервера"
            throw AvatarRegisterWorkerError.badStatus(code: httpResponse.statusCode, message: serverMessage)
        }
    }

    private func makeMultipartBody(
        boundary: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append(Data("--\(boundary)\(lineBreak)".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"avatar\"; filename=\"\(fileName)\"\(lineBreak)".utf8))
        body.append(Data("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".utf8))
        body.append(imageData)
        body.append(Data(lineBreak.utf8))
        body.append(Data("--\(boundary)--\(lineBreak)".utf8))

        return body
    }
}
