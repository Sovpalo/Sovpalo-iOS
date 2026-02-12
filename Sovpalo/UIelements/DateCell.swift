//
//  DateCell.swift
//  Sovpalo
//
//  Created by Jovana on 28.1.26.
//

import SwiftUI

struct DatePill: View {
    let weekdayShort: String
    let dayNumber: String
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(weekdayShort)
                .font(.subheadline)

            Text(dayNumber)
                .font(.headline)

            if isToday {
                Circle()
                    .frame(width: 6, height: 6)
            }
        }
        .foregroundColor(isSelected ? .white : .primary)
        .frame(width: 56, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(isSelected ? Color.brandBlue : Color.clear)
        )
        .onTapGesture {
            onTap()
        }
    }
}

