//
//  AvatarRegisterPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 22.04.2026.
//

import Foundation

protocol AvatarRegisterPresenterProtocol: AnyObject {
    func presentLoading(_ isLoading: Bool)
    func presentUploadError(_ message: String)
    func presentRouteToFirstGroup()
}

final class AvatarRegisterPresenter: AvatarRegisterPresenterProtocol {
    weak var vc: AvatarRegisterVC?

    func presentLoading(_ isLoading: Bool) {
        vc?.setUploadLoading(isLoading)
    }

    func presentUploadError(_ message: String) {
        vc?.showErrorAlert(message: message)
    }

    func presentRouteToFirstGroup() {
        vc?.navigateToFirstGroup()
    }
}
