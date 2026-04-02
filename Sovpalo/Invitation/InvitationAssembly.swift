//
//  InvitationAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit

import UIKit

final class InvitationAssembly {
    static func assembly() -> InvitationVC {
        let vc = InvitationVC()
        let interactor = InvitationInteractor()
        let presenter = InvitationPresenter()
        let keychain = KeychainService()

        let worker = InvitationWorker(
            baseURL: Server.url,
            tokenProvider: {
                guard let tokenData = keychain.getData(forKey: "auth.token") else {
                    return nil
                }
                return String(data: tokenData, encoding: .utf8)
            }
        )

        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc

        return vc
    }
}
