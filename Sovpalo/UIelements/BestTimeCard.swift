//
//  HorizontalScrollCalendar.swift
//  Sovpalo
//
//  Created by Jovana on 3.2.26.
//
import UIKit
import SwiftUI

struct BestTimeCard: View {
    @ObservedObject var presenter: MainScreenPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Наиболее удобное время:")
                .font(.headline)

            Text(presenter.bestTimeText)
                .font(.title3.bold())
                .foregroundColor(.brandBlue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}
