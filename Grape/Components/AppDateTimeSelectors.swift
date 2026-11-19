import SwiftUI

struct AppDateQuickOption: Identifiable, Equatable {
    let label: String
    let component: Calendar.Component
    let value: Int

    var id: String { label }

    static let today = AppDateQuickOption(label: "Today", component: .day, value: 0)
    static let tomorrow = AppDateQuickOption(label: "Tomorrow", component: .day, value: 1)
    static let nextWeek = AppDateQuickOption(label: "Next week", component: .day, value: 7)

    static func months(_ value: Int, label: String) -> AppDateQuickOption {
        AppDateQuickOption(label: label, component: .month, value: value)
    }
}

struct AppDateSelector: View {
    @Binding var selection: Date
    @State private var displayedMonth: Date
    @State private var isExpanded: Bool

    let title: String
    let iconName: String
    let tint: Color
    let quickOptions: [AppDateQuickOption]
    let startsExpanded: Bool
    let markersForDate: (Date) -> [Color]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(
        selection: Binding<Date>,
        title: String,
        iconName: String = "calendar",
        tint: Color = AppStyle.Palette.primary,
        quickOptions: [AppDateQuickOption] = [],
        startsExpanded: Bool = false,
        markersForDate: @escaping (Date) -> [Color] = { _ in [] }
    ) {
        _selection = selection
        _displayedMonth = State(initialValue: Self.startOfMonth(for: selection.wrappedValue))
        _isExpanded = State(initialValue: startsExpanded)
        self.title = title
        self.iconName = iconName
        self.tint = tint
        self.quickOptions = quickOptions
        self.startsExpanded = startsExpanded
        self.markersForDate = markersForDate
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(AppStyle.Palette.primarySoft.opacity(0.84), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(AppStyle.Typography.tiny)
                            .foregroundStyle(AppStyle.Palette.textSecondary)
                        Text(selection.formatted(.dateTime.weekday(.abbreviated).month().day().year()))
                            .font(AppStyle.Typography.label)
                            .foregroundStyle(AppStyle.Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if !quickOptions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(quickOptions) { option in
                            Button {
                                selectQuickDate(option)
                            } label: {
                                Text(option.label)
                                    .font(AppStyle.Typography.tiny)
                                    .foregroundStyle(tint)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(AppStyle.Palette.primarySoft.opacity(0.72))
                                            .overlay(
                                                Capsule()
                                                    .stroke(tint.opacity(0.10), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                calendarBody
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppStyle.Palette.surface.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppStyle.Palette.glassHighlight.opacity(0.9), lineWidth: 1)
                )
        )
        .onChange(of: selection) { _, newDate in
            let newMonth = Self.startOfMonth(for: newDate)
            guard !calendar.isDate(newMonth, equalTo: displayedMonth, toGranularity: .month) else { return }
            displayedMonth = newMonth
        }
    }

    private var calendarBody: some View {
        VStack(spacing: 10) {
            HStack {
                monthButton(systemName: "chevron.left") {
                    moveDisplayedMonth(by: -1)
                }

                Spacer()

                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(AppStyle.Typography.label)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer()

                monthButton(systemName: "chevron.right") {
                    moveDisplayedMonth(by: 1)
                }
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    dayCell(for: date)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppStyle.Palette.surface.opacity(0.92),
                            AppStyle.Palette.primarySoft.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[first..<symbols.count]) + Array(symbols[0..<first])
    }

    private var calendarDays: [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: displayedMonth),
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingSlots = (weekday - calendar.firstWeekday + 7) % 7
        let monthDates: [Date?] = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        var days = Array(repeating: Date?.none, count: leadingSlots) + monthDates
        let trailingSlots = (7 - days.count % 7) % 7
        days += Array(repeating: Date?.none, count: trailingSlots)
        return days
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(AppStyle.Palette.primarySoft.opacity(0.75), in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dayCell(for date: Date?) -> some View {
        if let date {
            let selected = calendar.isDate(date, inSameDayAs: selection)
            let today = calendar.isDateInToday(date)
            let markers = Array(markersForDate(date).prefix(3))

            Button {
                selectDate(date)
            } label: {
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(AppStyle.Typography.caption.monospacedDigit())
                        .foregroundStyle(selected ? Color.white : AppStyle.Palette.textPrimary)
                        .frame(width: 30, height: 30)
                        .background {
                            if selected {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [tint, AppStyle.Palette.accent],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else if today {
                                Circle()
                                    .fill(AppStyle.Palette.primarySoft.opacity(0.58))
                            }
                        }
                        .overlay {
                            if today && !selected {
                                Circle()
                                    .stroke(AppStyle.Palette.accent.opacity(0.42), lineWidth: 1)
                            }
                        }

                    HStack(spacing: 2) {
                        ForEach(Array(markers.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(selected ? Color.white.opacity(0.88) : color)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 5)
                    .opacity(markers.isEmpty ? 0 : 1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 39)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(height: 34)
        }
    }

    private func moveDisplayedMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
            displayedMonth = Self.startOfMonth(for: newMonth)
        }
    }

    private func selectDate(_ date: Date) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            selection = combiningDate(date, withTimeFrom: selection)
            if !startsExpanded {
                isExpanded = false
            }
        }
    }

    private func selectQuickDate(_ option: AppDateQuickOption) {
        let baseDate = calendar.startOfDay(for: .now)
        guard let date = calendar.date(byAdding: option.component, value: option.value, to: baseDate) else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
            selection = combiningDate(date, withTimeFrom: selection)
            displayedMonth = Self.startOfMonth(for: date)
            if !startsExpanded {
                isExpanded = false
            }
        }
    }

    private func combiningDate(_ date: Date, withTimeFrom source: Date) -> Date {
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: source)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second ?? 0
        return calendar.date(from: dateComponents) ?? date
    }

    private static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

struct AppTimeSelector: View {
    @Binding var selection: Date

    let title: String
    let iconName: String
    let tint: Color

    private let calendar = Calendar.current

    init(
        selection: Binding<Date>,
        title: String,
        iconName: String = "clock",
        tint: Color = AppStyle.Palette.primary
    ) {
        _selection = selection
        self.title = title
        self.iconName = iconName
        self.tint = tint
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(AppStyle.Palette.primarySoft.opacity(0.84), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                    Text(selection.formatted(.dateTime.hour().minute()))
                        .font(AppStyle.Typography.label.monospacedDigit())
                        .foregroundStyle(AppStyle.Palette.textPrimary)
                }

                Spacer(minLength: 8)
            }

            LazyVGrid(columns: timeColumns, spacing: 10) {
                timeStepper(title: "Hour", value: twoDigit(displayHour)) {
                    adjustHour(by: -1)
                } increment: {
                    adjustHour(by: 1)
                }

                timeStepper(title: "Minute", value: twoDigit(minute)) {
                    adjustMinute(by: -5)
                } increment: {
                    adjustMinute(by: 5)
                }
            }

            meridiemSelector
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppStyle.Palette.surface.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppStyle.Palette.glassHighlight.opacity(0.9), lineWidth: 1)
                )
        )
    }

    private var hour24: Int {
        calendar.component(.hour, from: selection)
    }

    private var timeColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var minute: Int {
        calendar.component(.minute, from: selection)
    }

    private var displayHour: Int {
        let value = hour24 % 12
        return value == 0 ? 12 : value
    }

    private var isPM: Bool {
        hour24 >= 12
    }

    private var meridiemSelector: some View {
        VStack(spacing: 6) {
            Text("AM/PM")
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 4) {
                meridiemButton("AM", active: !isPM) {
                    setMeridiem(isPM: false)
                }

                meridiemButton("PM", active: isPM) {
                    setMeridiem(isPM: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppStyle.Palette.surface.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func timeStepper(
        title: String,
        value: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)

            HStack(spacing: 5) {
                stepButton(systemName: "minus", action: decrement)

                Text(value)
                    .font(AppStyle.Typography.numericTime)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                    .frame(width: 34)

                stepButton(systemName: "plus", action: increment)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppStyle.Palette.surface.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(AppStyle.Palette.primarySoft.opacity(0.72), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func meridiemButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(active ? Color.white : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(active ? tint : AppStyle.Palette.primarySoft.opacity(0.72))
                )
        }
        .buttonStyle(.plain)
    }

    private func adjustHour(by delta: Int) {
        let nextHour = (hour24 + delta + 24) % 24
        setTime(hour: nextHour, minute: minute)
    }

    private func adjustMinute(by delta: Int) {
        let totalMinutes = hour24 * 60 + minute + delta
        let normalizedMinutes = (totalMinutes % 1440 + 1440) % 1440
        setTime(hour: normalizedMinutes / 60, minute: normalizedMinutes % 60)
    }

    private func setMeridiem(isPM targetIsPM: Bool) {
        var nextHour = hour24
        if targetIsPM && nextHour < 12 {
            nextHour += 12
        } else if !targetIsPM && nextHour >= 12 {
            nextHour -= 12
        }
        setTime(hour: nextHour, minute: minute)
    }

    private func setTime(hour: Int, minute: Int) {
        var components = calendar.dateComponents([.year, .month, .day], from: selection)
        components.hour = hour
        components.minute = minute
        components.second = 0
        selection = calendar.date(from: components) ?? selection
    }

    private func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
