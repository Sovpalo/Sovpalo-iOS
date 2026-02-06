//
//  RegistrationInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//

import Foundation

protocol SignInBusinessLogic {
    
}

final class SignInInteractor: SignInBusinessLogic {
    var presenter: SignInPresenterProtocol?
    var worker: SignInWorkerProtocol?
}
