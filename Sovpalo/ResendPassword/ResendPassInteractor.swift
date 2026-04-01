//
//  ResendPasswordInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 02.04.2026.
//

import Foundation

protocol ResendPassBusinessLogic {
    
}

final class ResendPassInteractor: ResendPassBusinessLogic {
    var presenter: ResendPassPresenterProtocol?
    var worker: ResendPassWorkerProtocol?
}
