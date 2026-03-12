//
//  MeetingsInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

protocol MeetingsBusinessLogic {
    
}

final class MeetingsInteractor: MeetingsBusinessLogic {
    var presenter: MeetingsPresenterProtocol?
    var worker: MeetingsWorkerProtocol?
}
