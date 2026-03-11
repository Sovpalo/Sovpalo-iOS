//
//  Models.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

struct Meeting {
    let id: Int
    let title: String
    let date: Date
    let place: String
    let address: String
    let isAttending: Bool
    let isPast: Bool
}
