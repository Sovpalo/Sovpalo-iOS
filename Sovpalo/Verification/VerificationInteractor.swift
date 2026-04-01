//
//  VerificationInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol VerificationBusinessLogic {
    
}

final class VerificationInteractor: VerificationBusinessLogic {
    var presenter: VerificationPresenterProtocol?
    var worker: VerifivationWorkerProtocol?
}
