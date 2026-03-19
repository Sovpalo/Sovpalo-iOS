//
//  MeetingsInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

protocol MeetingsBusinessLogic {
    func loadMeetings()
}

final class MeetingsInteractor: MeetingsBusinessLogic {
    let company: Company

    var presenter: MeetingsPresenterProtocol?
    var worker: MeetingsWorkerProtocol?

    init(company: Company) {
        self.company = company
    }
    
    func loadMeetings() {
        print("Load meetings for company id: \(company.id)")
    }
}
