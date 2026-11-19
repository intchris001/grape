import SwiftUI

struct ScheduleBoardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedDate = Date()
    @State private var draftTitle = ""
    @State private var draftSubtitle = ""
    @State private var editingEntry: ScheduleEntry?

    private var selectedEntries: [ScheduleEntry] {
        appState.scheduleEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedTasks: [TaskRecord] {
        appState.tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: selectedDate) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SurfaceCard(title: "Pick Date", iconAssetName: "Timetable") {
                    AppDateSelector(
                        selection: $selectedDate,
                        title: "Schedule date",
                        iconName: "calendar",
                        tint: AppStyle.Palette.primary,
                        quickOptions: [.today, .tomorrow, .nextWeek],
                        startsExpanded: true,
                        markersForDate: dateMarkers(for:)
                    )
                }

                if selectedEntries.isEmpty {
                    SurfaceCard(
                        title: "Schedule",
                        iconAssetName: "Timetable",
                        trailingText: "\(selectedEntries.count)"
                    ) {
                        EmptyStateView(
                            iconName: "calendar.badge.exclamationmark",
                            title: "Free Day!",
                            message: "No schedules for this date."
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("SCHEDULE").font(AppStyle.Typography.section).foregroundStyle(AppStyle.Palette.textPrimary)
                            Spacer()
                            Text("\(selectedEntries.count)")
                                .font(AppStyle.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(AppStyle.Palette.primary, in: Capsule())
                        }.padding(.horizontal, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(Array(selectedEntries.enumerated()), id: \.element.id) { index, item in
                                    SurfaceCard(title: "Event", iconAssetName: "Timetable") {
                                        scheduleRow(item)
                                    }
                                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 16)
                                    .scrollTransition(topLeading: .interactive, bottomTrailing: .interactive) { effect, phase in
                                        effect
                                            .scaleEffect(1.0 - abs(phase.value) * 0.1)
                                            .opacity(1.0 - abs(phase.value) * 0.3)
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .padding(.horizontal, -20)
                        .contentMargins(20, for: .scrollContent)
                    }
                }

                if selectedTasks.isEmpty {
                    SurfaceCard(
                        title: "Tasks Due",
                        iconAssetName: "Task",
                        trailingText: "\(selectedTasks.count)"
                    ) {
                        EmptyStateView(
                            iconName: "checkmark.seal",
                            title: "No Due Tasks",
                            message: "No tasks are due on this date."
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("TASKS DUE").font(AppStyle.Typography.section).foregroundStyle(AppStyle.Palette.textPrimary)
                            Spacer()
                            Text("\(selectedTasks.count)")
                                .font(AppStyle.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(AppStyle.Palette.primary, in: Capsule())
                        }.padding(.horizontal, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(Array(selectedTasks.enumerated()), id: \.element.id) { index, task in
                                    SurfaceCard(title: "Task", iconAssetName: "Task") {
                                        TaskItemRow(
                                            task: task,
                                            assigneeName: appState.displayName(for: task.assigneeMemberID),
                                            onToggle: {
                                                appState.toggleTask(id: task.id)
                                            }
                                        )
                                    }
                                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 16)
                                    .scrollTransition(topLeading: .interactive, bottomTrailing: .interactive) { effect, phase in
                                        effect
                                            .scaleEffect(1.0 - abs(phase.value) * 0.1)
                                            .opacity(1.0 - abs(phase.value) * 0.3)
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .padding(.horizontal, -20)
                        .contentMargins(20, for: .scrollContent)
                    }
                }

                SurfaceCard(title: "Add Schedule", iconAssetName: "Timetable") {
                    VStack(spacing: 10) {
                        TextField("Title", text: $draftTitle)
                            .glassInputField()
                        TextField("Subtitle (optional)", text: $draftSubtitle)
                            .glassInputField()

                        AppDateSelector(
                            selection: $selectedDate,
                            title: "Date",
                            iconName: "calendar",
                            tint: AppStyle.Palette.primary,
                            quickOptions: [.today, .tomorrow, .nextWeek]
                        )

                        AppTimeSelector(
                            selection: $selectedDate,
                            title: "Time",
                            tint: AppStyle.Palette.primary
                        )

                        Button("Create Schedule") {
                            appState.addSchedule(
                                title: draftTitle,
                                subtitle: draftSubtitle.isEmpty ? nil : draftSubtitle,
                                date: selectedDate
                            )
                            draftTitle = ""
                            draftSubtitle = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppStyle.Palette.primary)
                        .font(AppStyle.Typography.label)
                        .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 116)
        }
        .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    AppStyle.Haptic.play(.light)
                    selectedDate = Date()
                } label: {
                    Text("Today")
                        .font(AppStyle.Typography.label)
                        .foregroundStyle(Calendar.current.isDateInToday(selectedDate) ? AppStyle.Palette.textSecondary : AppStyle.Palette.primary)
                }
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
        }
        .sheet(item: $editingEntry) { entry in
            ScheduleEditorSheet(
                entry: entry,
                onSave: { title, subtitle, date in
                    _ = appState.updateSchedule(
                        id: entry.id,
                        title: title,
                        subtitle: subtitle,
                        date: date
                    )
                    selectedDate = date
                    editingEntry = nil
                },
                onDelete: {
                    appState.deleteSchedule(id: entry.id)
                    editingEntry = nil
                }
            )
        }
    }

    private func dateMarkers(for date: Date) -> [Color] {
        var markers: [Color] = []
        if appState.scheduleEntries.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            markers.append(AppStyle.Palette.primary)
        }
        if appState.tasks.contains(where: { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }) {
            markers.append(AppStyle.Palette.accent)
        }
        return markers
    }

    private func scheduleRow(_ item: ScheduleEntry) -> some View {
        Button {
            editingEntry = item
        } label: {
            HStack(spacing: 10) {
                ScheduleTimelineRow(item: item, showTimeline: true)

                Image(systemName: "pencil.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppStyle.Palette.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingEntry = item
            } label: {
                Label("Edit Schedule", systemImage: "pencil")
            }

            Button(role: .destructive) {
                appState.deleteSchedule(id: item.id)
            } label: {
                Label("Delete Schedule", systemImage: "trash")
            }
        }
    }
}

private struct ScheduleEditorSheet: View {
    let entry: ScheduleEntry
    let onSave: (String, String?, Date) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var subtitle: String
    @State private var date: Date

    init(
        entry: ScheduleEntry,
        onSave: @escaping (String, String?, Date) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: entry.title)
        _subtitle = State(initialValue: entry.subtitle ?? "")
        _date = State(initialValue: entry.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    TextField("Title", text: $title)
                        .glassInputField()
                    TextField("Subtitle (optional)", text: $subtitle)
                        .glassInputField()

                    AppDateSelector(
                        selection: $date,
                        title: "Date",
                        iconName: "calendar",
                        tint: AppStyle.Palette.primary,
                        quickOptions: [.today, .tomorrow, .nextWeek]
                    )

                    AppTimeSelector(selection: $date, title: "Time", tint: AppStyle.Palette.primary)

                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Schedule", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .font(AppStyle.Typography.label)
                }
                .padding(20)
            }
            .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(title, subtitle.isEmpty ? nil : subtitle, date)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScheduleBoardView()
            .environmentObject(AppState())
    }
}
