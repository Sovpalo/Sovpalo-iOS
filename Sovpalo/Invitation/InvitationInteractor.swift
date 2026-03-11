//
//  InvitationInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

protocol InvitationBusinessLogic {
    
}

final class InvitationInteractor: InvitationBusinessLogic {
    var presenter: InvitationPresenterProtocol?
    var worker: InvitationWorkerProtocol?
}
