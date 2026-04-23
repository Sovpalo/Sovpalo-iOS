import Foundation

struct CompanyAvatarHeader: Decodable {
    let id: Int
    let name: String
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarURL = "avatar_url"
    }
}

enum CompanyAvatarWorkerError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case invalidResponse
    case badStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .tokenNotFound:
            return "Не найден токен авторизации"
        case .tokenDecodingFailed:
            return "Не удалось прочитать токен авторизации"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case let .badStatus(code, message):
            if let data = message.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let readable = jsonObject["message"] as? String,
               !readable.isEmpty {
                return readable
            }
            return message.isEmpty ? "Ошибка сервера (\(code))" : message
        }
    }
}

final class CompanyAvatarWorker {
    private let baseURL: URL?
    private let session: URLSession
    private let keychain: KeychainLogic
    private static let decoder = JSONDecoder()

    init(
        baseURL: URL? = URL(string: Server.url),
        session: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    func fetchAvatarData(from avatarURL: String) async throws -> Data {
        guard let baseURL else {
            throw CompanyAvatarWorkerError.invalidURL
        }

        let resolvedURL: URL
        if let absoluteURL = URL(string: avatarURL), absoluteURL.scheme != nil {
            resolvedURL = absoluteURL
        } else {
            resolvedURL = baseURL.appendingPathComponent(avatarURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        var request = URLRequest(url: resolvedURL)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CompanyAvatarWorkerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Не удалось загрузить аватар"
            throw CompanyAvatarWorkerError.badStatus(code: httpResponse.statusCode, message: message)
        }

        return data
    }

    func fetchCompany(companyID: Int) async throws -> CompanyAvatarHeader {
        let request = try authorizedRequest(path: "companies/\(companyID)", method: "GET")
        let data = try await performDataRequest(request)
        if let body = String(data: data, encoding: .utf8) {
            print("[CompanyAvatarWorker] GET /companies/\(companyID) response: \(body)")
        }
        return try Self.decoder.decode(CompanyAvatarHeader.self, from: data)
    }

    func uploadAvatar(companyID: Int, imageData: Data, fileName: String, mimeType: String) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try authorizedRequest(path: "companies/\(companyID)", method: "PATCH")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = makeMultipartBody(boundary: boundary, imageData: imageData, fileName: fileName, mimeType: mimeType)
        let data = try await performDataRequest(request)
        if let body = String(data: data, encoding: .utf8) {
            print("[CompanyAvatarWorker] PATCH /companies/\(companyID) upload response: \(body)")
        }
    }

    func deleteAvatar(companyID: Int) async throws {
        var request = try authorizedRequest(path: "companies/\(companyID)", method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["avatar_url": ""], options: [])
        let data = try await performDataRequest(request)
        if let body = String(data: data, encoding: .utf8) {
            print("[CompanyAvatarWorker] PATCH /companies/\(companyID) delete response: \(body)")
        }
    }

    private func authorizedRequest(path: String, method: String) throws -> URLRequest {
        guard let baseURL else {
            throw CompanyAvatarWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw CompanyAvatarWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw CompanyAvatarWorkerError.tokenDecodingFailed
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func performDataRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CompanyAvatarWorkerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Ошибка сервера"
            throw CompanyAvatarWorkerError.badStatus(code: httpResponse.statusCode, message: message)
        }

        return data
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
