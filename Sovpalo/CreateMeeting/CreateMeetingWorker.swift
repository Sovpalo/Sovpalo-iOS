import Foundation

struct CreateMeetingPhotoUpload {
    let data: Data
    let fileName: String
    let mimeType: String
}

struct CreateMeetingPayload {
    let title: String
    let description: String?
    let startTime: String
    let endTime: String?
    let companyId: Int?
}

enum CreateMeetingWorkerError: LocalizedError {
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
            if let data = message.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let readable = jsonObject["message"] as? String,
               !readable.isEmpty {
                return readable
            }
            return "Ошибка создания встречи (\(code)): \(message)"
        }
    }
}

protocol CreateMeetingWorkerProtocol {
    func createMeeting(payload: CreateMeetingPayload, photo: CreateMeetingPhotoUpload?) async throws
}

final class CreateMeetingWorker: CreateMeetingWorkerProtocol {
    private let keychain: KeychainLogic

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func createMeeting(payload: CreateMeetingPayload, photo: CreateMeetingPhotoUpload?) async throws {
        guard let url = URL(string: Server.url + "/events") else {
            throw CreateMeetingWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw CreateMeetingWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw CreateMeetingWorkerError.tokenDecodingFailed
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = makeMultipartBody(boundary: boundary, payload: payload, photo: photo)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CreateMeetingWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw CreateMeetingWorkerError.badStatus(code: httpResponse.statusCode, message: serverMessage)
        }
    }

    private func makeMultipartBody(
        boundary: String,
        payload: CreateMeetingPayload,
        photo: CreateMeetingPhotoUpload?
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func appendField(name: String, value: String) {
            body.append(Data("--\(boundary)\(lineBreak)".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)".utf8))
            body.append(Data(value.utf8))
            body.append(Data(lineBreak.utf8))
        }

        appendField(name: "title", value: payload.title)
        appendField(name: "start_time", value: payload.startTime)

        if let description = payload.description, !description.isEmpty {
            appendField(name: "description", value: description)
        }

        if let endTime = payload.endTime, !endTime.isEmpty {
            appendField(name: "end_time", value: endTime)
        }

        if let companyId = payload.companyId {
            appendField(name: "company_id", value: String(companyId))
        }

        if let photo {
            body.append(Data("--\(boundary)\(lineBreak)".utf8))
            body.append(
                Data(
                    "Content-Disposition: form-data; name=\"photo\"; filename=\"\(photo.fileName)\"\(lineBreak)"
                        .utf8
                )
            )
            body.append(Data("Content-Type: \(photo.mimeType)\(lineBreak)\(lineBreak)".utf8))
            body.append(photo.data)
            body.append(Data(lineBreak.utf8))
        }

        body.append(Data("--\(boundary)--\(lineBreak)".utf8))
        return body
    }
}
