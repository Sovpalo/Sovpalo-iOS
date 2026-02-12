//
//  RegisterInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import Foundation

protocol RegisterBusinessLogic {
    
}

final class RegisterInteractor: RegisterBusinessLogic {
    var presenter: RegisterPresenterProtocol?
    var worker: RegisterWorkerProtocol?
}
