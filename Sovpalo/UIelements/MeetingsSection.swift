//
//  CardContainer.swift
//  Sovpalo
//
//  Created by Jovana on 28.1.26.
//

import UIKit
import SwiftUI

struct MeetingsSection: View {
    @ObservedObject var presenter: MainScreenPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header row with title and trailing people button
            HStack {
                Text(presenter.todayTitle)
                    .font(.title2.bold())

                Spacer()

                Button(action: {
                    // Functionless for now
                }) {
                    Image(systemName: "person.2.fill")
                        .font(.title3) // larger icon
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40) // larger tap target
                        .background(
                            Circle()
                                .fill(Color.brandBlue)
                        )
                }
                .accessibilityLabel("Друзья")
            }

            if let meeting = presenter.meetings.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(meeting.timeText) — \(meeting.title)")
                        .font(.headline)

                    Text(meeting.locationText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                )
            }
        }
    }
}
