//
//  AvatarRegisterInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 22.04.2026.
//

import Foundation

protocol AvatarRegisterBusinessLogic {
    func skipAvatarUpload()
    func uploadAvatar(imageData: Data, fileName: String, mimeType: String)
}

final class AvatarRegisterInteractor: AvatarRegisterBusinessLogic {
    private var presenter: AvatarRegisterPresenterProtocol?
    private var worker: AvatarRegisterWorkerProtocol?

    init(presenter: AvatarRegisterPresenterProtocol? = nil, worker: AvatarRegisterWorkerProtocol? = nil) {
        self.presenter = presenter
        self.worker = worker
    }

    func skipAvatarUpload() {
        print("[AvatarRegisterInteractor] Avatar upload skipped by user")
        presenter?.presentRouteToFirstGroup()
    }

    func uploadAvatar(imageData: Data, fileName: String, mimeType: String) {
        guard let worker else {
            print("[AvatarRegisterInteractor] Worker is unavailable")
            presenter?.presentUploadError("Сервис загрузки недоступен")
            return
        }

        print("[AvatarRegisterInteractor] Starting avatar upload: fileName=\(fileName), mimeType=\(mimeType), size=\(imageData.count) bytes")
        presenter?.presentLoading(true)

        Task { [weak self] in
            do {
                try await worker.uploadAvatar(imageData: imageData, fileName: fileName, mimeType: mimeType)
                await MainActor.run { [weak self] in
                    print("[AvatarRegisterInteractor] Avatar upload finished successfully")
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentRouteToFirstGroup()
                }
            } catch {
                await MainActor.run { [weak self] in
                    print("[AvatarRegisterInteractor] Avatar upload failed: \(error.localizedDescription)")
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentUploadError(error.localizedDescription)
                }
            }
        }
    }
}
