import SwiftUI

struct FreeTimeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDate: Date
    let initialHoursByDate: [String: [Int]]
    let onSave: ([String: [Int]]) -> Void

    struct DayItem: Identifiable {
        let id = UUID()
        let weekday: String
        let date: Date
        let day: String
        var from: Date?
        var to: Date?
        var allDay: Bool
    }

    @State private var days: [DayItem] = []

    init(selectedDate: Date, initialHoursByDate: [String: [Int]] = [:], onSave: @escaping ([String: [Int]]) -> Void) {
        self.selectedDate = selectedDate
        self.initialHoursByDate = initialHoursByDate
        self.onSave = onSave

        var weekDays = FreeTimeEditorView.makeWeekDays(containing: selectedDate)

        for index in weekDays.indices {
            let calendar = Calendar.current
            let dayDate = weekDays[index].date
            let dayId = Self.dateId(from: dayDate)
            guard let initialHours = initialHoursByDate[dayId], !initialHours.isEmpty else { continue }

            var startComps = calendar.dateComponents([.year, .month, .day], from: dayDate)
            var endComps   = calendar.dateComponents([.year, .month, .day], from: dayDate)
            startComps.hour = initialHours.min()
            startComps.minute = 0
            endComps.hour = initialHours.max()
            endComps.minute = 0
            weekDays[index].from   = calendar.date(from: startComps)
            weekDays[index].to     = calendar.date(from: endComps)
            weekDays[index].allDay = initialHours.count >= 20
        }

        _days = State(initialValue: weekDays)
    }

    var body: some View {
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
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            doneButtonBar
        }
        .navigationTitle("Свободное время")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var doneButtonBar: some View {
        HStack {
            Spacer()

            Button {
                onSave(collectedHoursByDate())
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
        .padding(.top, 12)
        .padding(.bottom, AppLayout.floatingButtonBottomOffset + 8)
        .background(Color(.systemGroupedBackground))
    }

    private func collectedHoursByDate() -> [String: [Int]] {
        let calendar = Calendar.current
        return days.reduce(into: [String: [Int]]()) { result, day in
            let dayId = Self.dateId(from: day.date)

            if day.allDay {
                result[dayId] = Array(0...23)
                return
            }

            guard let from = day.from, let to = day.to else {
                result[dayId] = []
                return
            }

            let fromHour = calendar.component(.hour, from: from)
            let toHour   = calendar.component(.hour, from: to)

            if fromHour < toHour {
                result[dayId] = Array(fromHour...toHour)
            } else if fromHour == toHour {
                result[dayId] = [fromHour]
            } else {
                result[dayId] = []
            }
        }
    }

    private static func makeWeekDays(containing date: Date) -> [DayItem] {
        let calendar = Calendar(identifier: .gregorian)
        let monday = startOfWeekMonday(for: date)
        let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        var result: [DayItem] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let dayNumber = String(calendar.component(.day, from: date))
            result.append(DayItem(weekday: weekdaySymbols[offset], date: date, day: dayNumber, allDay: false))
        }
        return result
    }

    private static func startOfWeekMonday(for date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday: Int = weekday == 1 ? 6 : weekday - 2
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    private static func dateId(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct DayRow: View {
    @Binding var day: FreeTimeEditorView.DayItem
    @State private var showFromPicker = false
    @State private var showToPicker = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.weekday)
                    .font(.subheadline.weight(.semibold))
                Text(day.day)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, alignment: .leading)

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
        .onChange(of: day.from) { _, newFrom in
            guard let from = newFrom, let to = day.to else { return }
            if from > to { day.to = from }
        }
        .onChange(of: day.to) { _, newTo in
            guard let to = newTo, let from = day.from else { return }
            if to < from { day.from = to }
        }
    }
}

private struct TimePickerButton: View {
    @Binding var date: Date?
    @Binding var isPresented: Bool
    private let placeholder = "— — : — —"
    @State private var tempDate: Date = defaultTime()

    var body: some View {
        Button {
            tempDate = date.map { roundedToHour($0) } ?? Self.defaultTime()
            isPresented = true
        } label: {
            Text(date.map { Self.formatter.string(from: $0) } ?? placeholder)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(date == nil ? .secondary : .primary)
                .frame(width: 96)
                .padding(.vertical, 8)
                .background(Capsule(style: .continuous).fill(Color(.systemGray6)))
        }
        .sheet(isPresented: $isPresented) {
            VStack(spacing: 16) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { tempDate },
                        set: { tempDate = roundedToHour($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                HStack(spacing: 12) {
                    Button("Отмена") { isPresented = false }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)))

                    Button("Выбрать") {
                        date = tempDate
                        isPresented = false
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.brandBlue))
                    .foregroundColor(.white)
                }
                .padding(.top, 8)
            }
            .padding()
            .presentationDetents([.height(320), .medium])
        }
    }

    private static func defaultTime() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func roundedToHour(_ date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "HH:mm"
        return f
    }()
}

//#Preview {
//    NavigationStack {
//        FreeTimeEditorView { hours in
//            print(hours)
//        }
//    }
//}
