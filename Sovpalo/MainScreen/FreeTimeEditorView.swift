import SwiftUI

struct FreeTimeEditorView: View {
    @Environment(\.dismiss) private var dismiss

    struct DayItem: Identifiable {
        let id = UUID()
        let weekday: String   // "Пн"
        let day: String       // "24"
        var from: Date?       // nil means no time selected yet
        var to: Date?
        var allDay: Bool
    }

    @State private var days: [DayItem] = [
        .init(weekday: "Пн", day: "24", from: nil, to: nil, allDay: false),
        .init(weekday: "Вт", day: "25", from: nil, to: nil, allDay: false),
        .init(weekday: "Ср", day: "26", from: nil, to: nil, allDay: false),
        .init(weekday: "Чт", day: "27", from: nil, to: nil, allDay: false),
        .init(weekday: "Пт", day: "28", from: nil, to: nil, allDay: false),
        .init(weekday: "Сб", day: "29", from: nil, to: nil, allDay: false),
        .init(weekday: "Вс", day: "30", from: nil, to: nil, allDay: false)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Card-like table container
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($days) { $day in
                        DayRow(day: $day)
                        if day.id != days.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            // Bottom button (not full width)
            HStack {
                Spacer()
                Button {
                    // Save action – integrate with interactor later
                    dismiss()
                } label: {
                    Text("Готово")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.brandBlue)
                        )
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Свободное время")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Свободное время")
                        .font(.headline)
                    Text("24.06 – 30.06")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.brandBlue)
                }
            }
        }
    }
}

private struct DayRow: View {
    @Binding var day: FreeTimeEditorView.DayItem
    @State private var showFromPicker = false
    @State private var showToPicker = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Day column
            VStack(alignment: .leading, spacing: 2) {
                Text(day.weekday)
                    .font(.subheadline.weight(.semibold))
                Text(day.day)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, alignment: .leading)

            // Free time interval
            VStack(alignment: .leading, spacing: 6) {
                Text("Свободное время")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text("с")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TimePickerButton(date: $day.from, isPresented: $showFromPicker)

                    Text("до")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TimePickerButton(date: $day.to, isPresented: $showToPicker)
                }
            }

            Spacer()

            // All day toggle
            VStack(alignment: .center, spacing: 6) {
                Text("Весь день")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Toggle("", isOn: $day.allDay)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        // Optional: keep logical consistency (from <= to) when both are set
        .onChange(of: day.from) { _, newFrom in
            guard let from = newFrom, let to = day.to else { return }
            if from > to {
                day.to = from
            }
        }
        .onChange(of: day.to) { _, newTo in
            guard let to = newTo, let from = day.from else { return }
            if to < from {
                day.from = to
            }
        }
    }
}

// A compact button that shows either placeholder “— — : — —” or formatted time,
// and presents a system wheel time picker in a sheet.
private struct TimePickerButton: View {
    @Binding var date: Date?
    @Binding var isPresented: Bool

    private let placeholder = "— — : — —"
    @State private var tempDate: Date = defaultTime()

    var body: some View {
        Button {
            // Initialize tempDate from current value or default
            if let current = date {
                tempDate = current
            } else {
                tempDate = Self.defaultTime()
            }
            isPresented = true
        } label: {
            Text(date.map { Self.formatter.string(from: $0) } ?? placeholder)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(date == nil ? .secondary : .primary)
                .frame(width: 96)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.systemGray6))
                )
        }
        .sheet(isPresented: $isPresented) {
            VStack(spacing: 16) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { tempDate },
                        set: { tempDate = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                HStack(spacing: 12) {
                    Button("Отмена") {
                        isPresented = false
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    )

                    Button("Выбрать") {
                        date = tempDate
                        isPresented = false
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Color.brandBlue)
                    )
                    .foregroundColor(.white)
                }
                .padding(.top, 8)
            }
            .padding()
            .presentationDetents([.height(320), .medium]) // compact picker sheet
        }
    }

    // MARK: - Helpers

    private static func defaultTime() -> Date {
        // Use today at 09:00 by default
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "HH:mm"
        return f
    }()
}
