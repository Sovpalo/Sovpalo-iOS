//
//  EditMeetingWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import Foundation
import UIKit
import ImageIO

struct EditMeetingPhotoUpload {
    let data: Data
    let fileName: String
    let mimeType: String
}

struct EditMeetingPayload {
    let title: String
    let description: String?
    let startTime: String
    let endTime: String?
    let companyId: Int?
    let shouldRemovePhoto: Bool
}

enum EditMeetingWorkerError: LocalizedError {
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
            return "Ошибка изменения встречи (\(code)): \(message)"
        }
    }
}

protocol EditMeetingWorkerProtocol {
    func updateMeeting(eventId: Int, payload: EditMeetingPayload, photo: EditMeetingPhotoUpload?) async throws
    func fetchImage(from rawURL: String, targetSize: CGSize) async -> UIImage?
}

final class EditMeetingWorker: EditMeetingWorkerProtocol {
    private let keychain: KeychainLogic
    private let imageLoader = EditMeetingImageLoader()

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func updateMeeting(eventId: Int, payload: EditMeetingPayload, photo: EditMeetingPhotoUpload?) async throws {
        guard let url = URL(string: Server.url + "/events/\(eventId)") else {
            throw EditMeetingWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw EditMeetingWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw EditMeetingWorkerError.tokenDecodingFailed
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = makeMultipartBody(boundary: boundary, payload: payload, photo: photo)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EditMeetingWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw EditMeetingWorkerError.badStatus(code: httpResponse.statusCode, message: serverMessage)
        }
    }

    func fetchImage(from rawURL: String, targetSize: CGSize) async -> UIImage? {
        await imageLoader.loadImage(from: rawURL, targetSize: targetSize)
    }

    private func makeMultipartBody(
        boundary: String,
        payload: EditMeetingPayload,
        photo: EditMeetingPhotoUpload?
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

        if payload.shouldRemovePhoto {
            appendField(name: "photo_url", value: "")
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

private actor EditMeetingImageLoader {
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        session = URLSession(configuration: configuration)
        cache.countLimit = 80
    }

    func loadImage(from rawURL: String, targetSize: CGSize) async -> UIImage? {
        let cacheKey = "\(rawURL)-\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let resolvedURL = resolvedURL(from: rawURL) else {
            return nil
        }

        var request = URLRequest(url: resolvedURL)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = downsampleImage(data: data, targetSize: targetSize) else {
                return nil
            }

            cache.setObject(image, forKey: cacheKey)
            return image
        } catch {
            return nil
        }
    }

    private func resolvedURL(from rawURL: String) -> URL? {
        if let absoluteURL = URL(string: rawURL), absoluteURL.scheme != nil {
            return absoluteURL
        }

        guard let baseURL = URL(string: Server.url) else {
            return nil
        }

        return baseURL.appendingPathComponent(rawURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private func downsampleImage(data: Data, targetSize: CGSize) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let maxPixelSize = Int(max(targetSize.width, targetSize.height) * UIScreen.main.scale)
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
