//
//  VerificationPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation
import UIKit

protocol VerificationPresenterProtocol {
    func presentInitialState(email: String, flow: VerificationFlow)
    func presentLoading(_ isLoading: Bool)
    func presentVerificationSuccess(flow: VerificationFlow)
    func presentVerificationError(_ message: String)
}

final class VerificationPresenter: VerificationPresenterProtocol {
    weak var vc: VerificationVC?

    func presentInitialState(email: String, flow: VerificationFlow) {
        let maskedEmail = maskEmail(email)
        let text: String

        switch flow {
        case .registration:
            text = "На вашу почту \(maskedEmail) отправлен 4-х значный код подтверждения, введите его для успешной регистрации"
        case .forgotPassword:
            text = "На вашу почту \(maskedEmail) отправлен 4-х значный код подтверждения, введите его для сброса пароля. После успешного ввода, войдите в ваш аккаунт заново с новым паролем"
        }

        vc?.display(description: text, showsPasswordField: flow == .forgotPassword)
    }

    func presentLoading(_ isLoading: Bool) {
        vc?.setVerificationLoading(isLoading)
    }

    func presentVerificationSuccess(flow: VerificationFlow) {
        switch flow {
        case .registration:
            let uploadAvatar = AvatarRegisterAssembly.assembly()
            vc?.navigationController?.setViewControllers([uploadAvatar], animated: true)
        case .forgotPassword:
            let startVC = StartAssembly.assembly()
            vc?.navigationController?.setViewControllers([startVC], animated: true)
        }
    }

    func presentVerificationError(_ message: String) {
        let alert = UIAlertController(
            title: "Ошибка подтверждения",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc?.present(alert, animated: true)
    }

    private func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return email }

        let local = maskEmailPart(parts[0])
        let domainParts = parts[1].split(separator: ".", maxSplits: 1).map(String.init)

        guard let domainName = domainParts.first else {
            return "\(local)@***"
        }

        let maskedDomain = maskEmailPart(domainName)
        if domainParts.count == 2 {
            return "\(local)@\(maskedDomain).\(domainParts[1])"
        } else {
            return "\(local)@\(maskedDomain)"
        }
    }

    private func maskEmailPart(_ value: String) -> String {
        guard !value.isEmpty else { return "***" }
        if value.count == 1 { return "\(value)***" }
        if value.count == 2 {
            let chars = Array(value)
            return "\(chars[0])***"
        }

        let chars = Array(value)
        return "\(chars[0])***\(chars[chars.count - 1])"
    }
}
