//
//  IdeasListInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import Foundation

protocol IdeasListBusinessLogic {
    
}

final class IdeasListInteractor: IdeasListBusinessLogic {
    var presenter: IdeasListPresenterProtocol?
    var worker: IdeasListWorkerProtocol?
}
