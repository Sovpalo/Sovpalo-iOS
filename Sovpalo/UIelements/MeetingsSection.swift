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
            HStack {
                Text(presenter.todayTitle)
                    .font(.title2.bold())

                Spacer()
            }

            if presenter.meetings.isEmpty {
                Text("На сегодня встреч пока нет")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(presenter.meetings.enumerated()), id: \.offset) { _, meeting in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(meeting.timeText) — \(meeting.title)")
                                    .font(.headline)
                                    .lineLimit(2)

                                Text(meeting.locationText)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding()
                            .frame(width: 210, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                            )
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            }
        }
    }
}
