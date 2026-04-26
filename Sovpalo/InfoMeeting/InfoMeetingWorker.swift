//
//  InfoMeetingWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.03.2026.
//

import Foundation
import UIKit
import ImageIO

enum InfoMeetingWorkerError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case badServerResponse
    case badStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .tokenNotFound:
            return "Не найден токен авторизации"
        case .tokenDecodingFailed:
            return "Не удалось прочитать токен авторизации"
        case .badServerResponse:
            return "Некорректный ответ сервера"
        case let .badStatus(code, message):
            return "Ошибка сервера (\(code)): \(message)"
        }
    }
}

protocol InfoMeetingWorkerProtocol {
    func fetchCompanyEvent(companyId: Int, eventId: Int) async throws -> CompanyEventDTO
    func fetchAttendanceSummary(companyId: Int, eventId: Int) async throws -> EventAttendanceSummaryDTO
    func deleteEvent(eventId: Int) async throws
    func fetchImage(from rawURL: String, targetSize: CGSize) async -> UIImage?
}

final class InfoMeetingWorker: InfoMeetingWorkerProtocol {
    private let keychain: KeychainLogic
    private let imageLoader = InfoMeetingImageLoader()

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func fetchCompanyEvent(companyId: Int, eventId: Int) async throws -> CompanyEventDTO {
        let request = try makeRequest(
            path: Server.url + "/companies/\(companyId)/events/\(eventId)",
            method: "GET"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(CompanyEventDTO.self, from: data)
    }

    func fetchAttendanceSummary(companyId: Int, eventId: Int) async throws -> EventAttendanceSummaryDTO {
        let request = try makeRequest(
            path: Server.url + "/companies/\(companyId)/events/\(eventId)/attendance/summary",
            method: "GET"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(EventAttendanceSummaryDTO.self, from: data)
    }
    
    func deleteEvent(eventId: Int) async throws {
        let request = try makeRequest(
            path: Server.url + "/events/\(eventId)",
            method: "DELETE"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func fetchImage(from rawURL: String, targetSize: CGSize) async -> UIImage? {
        await imageLoader.loadImage(from: rawURL, targetSize: targetSize)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path) else {
            throw InfoMeetingWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw InfoMeetingWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw InfoMeetingWorkerError.tokenDecodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfoMeetingWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw InfoMeetingWorkerError.badStatus(code: httpResponse.statusCode, message: message)
        }
    }
}

private actor InfoMeetingImageLoader {
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
