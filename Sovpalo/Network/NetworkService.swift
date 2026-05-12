import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

struct MultipartFormFile {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

enum NetworkServiceError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case invalidResponse
    case badStatus(code: Int, message: String)
    case emptyResponse

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
            return readableMessage(from: message, fallback: "Ошибка сервера (\(code))")
        case .emptyResponse:
            return "Сервер вернул пустой ответ"
        }
    }

    private func readableMessage(from rawMessage: String, fallback: String) -> String {
        if let data = rawMessage.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = jsonObject["message"] as? String,
           !message.isEmpty {
            return message
        }

        return rawMessage.isEmpty ? fallback : rawMessage
    }
}

protocol NetworkServicing {
    func tokenString() throws -> String
    func data(
        path: String,
        method: HTTPMethod,
        authorized: Bool,
        body: Data?,
        contentType: String?,
        headers: [String: String]
    ) async throws -> Data
    func decoded<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        authorized: Bool,
        decoder: JSONDecoder,
        headers: [String: String]
    ) async throws -> Response
    func decoded<Response: Decodable, Body: Encodable>(
        path: String,
        method: HTTPMethod,
        authorized: Bool,
        body: Body,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        headers: [String: String]
    ) async throws -> Response
    func multipartDecoded<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        authorized: Bool,
        fields: [String: String],
        files: [MultipartFormFile],
        decoder: JSONDecoder,
        headers: [String: String]
    ) async throws -> Response
    func multipartData(
        path: String,
        method: HTTPMethod,
        authorized: Bool,
        fields: [String: String],
        files: [MultipartFormFile],
        headers: [String: String]
    ) async throws -> Data
}

final class NetworkService: NetworkServicing {
    private let baseURL: URL
    private let session: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL = URL(string: Server.url)!,
        session: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    func tokenString() throws -> String {
        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw NetworkServiceError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw NetworkServiceError.tokenDecodingFailed
        }

        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func data(
        path: String,
        method: HTTPMethod,
        authorized: Bool = false,
        body: Data? = nil,
        contentType: String? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        var request = try makeRequest(
            path: path,
            method: method,
            authorized: authorized,
            contentType: contentType,
            headers: headers
        )
        request.httpBody = body
        return try await perform(request)
    }

    func decoded<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        authorized: Bool = false,
        decoder: JSONDecoder = JSONDecoder(),
        headers: [String: String] = [:]
    ) async throws -> Response {
        let responseData = try await data(
            path: path,
            method: method,
            authorized: authorized,
            headers: headers
        )
        return try decode(Response.self, from: responseData, decoder: decoder)
    }

    func decoded<Response: Decodable, Body: Encodable>(
        path: String,
        method: HTTPMethod,
        authorized: Bool = false,
        body: Body,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        headers: [String: String] = [:]
    ) async throws -> Response {
        let requestBody = try encoder.encode(body)
        let responseData = try await data(
            path: path,
            method: method,
            authorized: authorized,
            body: requestBody,
            contentType: "application/json",
            headers: headers
        )
        return try decode(Response.self, from: responseData, decoder: decoder)
    }

    func multipartDecoded<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        authorized: Bool = false,
        fields: [String: String] = [:],
        files: [MultipartFormFile],
        decoder: JSONDecoder = JSONDecoder(),
        headers: [String: String] = [:]
    ) async throws -> Response {
        let responseData = try await multipartData(
            path: path,
            method: method,
            authorized: authorized,
            fields: fields,
            files: files,
            headers: headers
        )
        return try decode(Response.self, from: responseData, decoder: decoder)
    }

    func multipartData(
        path: String,
        method: HTTPMethod,
        authorized: Bool = false,
        fields: [String: String] = [:],
        files: [MultipartFormFile],
        headers: [String: String] = [:]
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = makeMultipartBody(boundary: boundary, fields: fields, files: files)
        return try await data(
            path: path,
            method: method,
            authorized: authorized,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)",
            headers: headers
        )
    }

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        authorized: Bool,
        contentType: String?,
        headers: [String: String]
    ) throws -> URLRequest {
        let url = try resolveURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authorized {
            request.setValue("Bearer \(try tokenString())", forHTTPHeaderField: "Authorization")
        }

        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        try OfflineTesting.throwIfNeeded()

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw NetworkServiceError.badStatus(code: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func decode<Response: Decodable>(
        _ type: Response.Type,
        from data: Data,
        decoder: JSONDecoder
    ) throws -> Response {
        guard !data.isEmpty else {
            throw NetworkServiceError.emptyResponse
        }

        return try decoder.decode(type, from: data)
    }

    private func resolveURL(_ path: String) throws -> URL {
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            return absoluteURL
        }

        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/\(normalizedPath)") else {
            throw NetworkServiceError.invalidURL
        }

        return url
    }

    private func makeMultipartBody(
        boundary: String,
        fields: [String: String],
        files: [MultipartFormFile]
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        fields.forEach { key, value in
            body.append(Data("--\(boundary)\(lineBreak)".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)".utf8))
            body.append(Data("\(value)\(lineBreak)".utf8))
        }

        files.forEach { file in
            body.append(Data("--\(boundary)\(lineBreak)".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\(lineBreak)".utf8))
            body.append(Data("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)".utf8))
            body.append(file.data)
            body.append(Data(lineBreak.utf8))
        }

        body.append(Data("--\(boundary)--\(lineBreak)".utf8))
        return body
    }
}
