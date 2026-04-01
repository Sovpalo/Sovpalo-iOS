//
//  ForgotPasswordInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol ForgotPasswordBusinessLogic {
    
}

final class ForgotPasswordInteractor: ForgotPasswordBusinessLogic {
    var presenter: ForgotPasswordPresenterProtocol?
    var worker: ForgorPasswordWorkerProtocol?
}
