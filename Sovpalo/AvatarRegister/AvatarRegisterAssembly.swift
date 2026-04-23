//
//  AvatarRegisterAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 22.04.2026.
//

import UIKit

final class AvatarRegisterAssembly {
    static func assembly() -> AvatarRegisterVC {
        let presenter = AvatarRegisterPresenter()
        let worker = AvatarRegisterWorker()
        let interactor = AvatarRegisterInteractor(presenter: presenter, worker: worker)
        let vc = AvatarRegisterVC(interactor: interactor)
        presenter.vc = vc

        return vc
    }
}
