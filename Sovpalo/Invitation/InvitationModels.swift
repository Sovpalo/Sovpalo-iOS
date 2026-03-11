//
//  Models.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

// MARK: - Model
struct Invitation {
    let id: Int
    let companyId: Int
    let companyName: String
    let invitedByUsername: String
    let status: String
    let createdAt: String
}
