import SwiftUI

struct TaskBoardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedFilter = 0
    @State private var draftTaskTitle = ""
    @State private var draftDueDate = Date()
    @State private var selectedAssigneeID: UUID?
    @State private var editingTask: TaskRecord?

    private var visibleTasks: [TaskRecord] {
        let base = appState.tasks
        let myMemberID = appState.currentMembership?.id

        switch selectedFilter {
        case 1:
            return base.filter { $0.assigneeMemberID == myMemberID }
        case 2:
            return base.filter { $0.assigneeMemberID == nil }
        case 3:
            return base.filter(\.isCompleted)
        default:
            return base
        }
    }

    private var completionRate: Double {
        let todayStart = Calendar.current.startOfDay(for: .now)
        let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        
        let todayTasks = visibleTasks.filter { $0.dueDate >= todayStart && $0.dueDate < tomorrowStart }
        if todayTasks.isEmpty { return .zero }
        
        let completed = todayTasks.filter(\.isCompleted).count
        return Double(completed) / Double(todayTasks.count)
    }

    private var visibleTaskSections: [(title: String, tasks: [TaskRecord])] {
        if selectedFilter == 3 {
            return [("Done", visibleTasks)]
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let incompleteTasks = visibleTasks.filter { !$0.isCompleted }
        let completedTasks = visibleTasks.filter(\.isCompleted)

        var sections: [(title: String, tasks: [TaskRecord])] = [
            ("Overdue", incompleteTasks.filter { $0.dueDate < todayStart }),
            ("Today", incompleteTasks.filter { calendar.isDateInToday($0.dueDate) }),
            ("Upcoming", incompleteTasks.filter { $0.dueDate >= tomorrowStart })
        ]

        if !completedTasks.isEmpty {
            sections.append(("Done", completedTasks))
        }

        return sections.filter { !$0.tasks.isEmpty }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Task filter", selection: $selectedFilter) {
                    Text("All").tag(0)
                    Text("Mine").tag(1)
                    Text("Unassigned").tag(2)
                    Text("Done").tag(3)
                }
                .pickerStyle(.segmented)
                .font(AppStyle.Typography.caption)
                .onChange(of: selectedFilter) { _, _ in
                    AppStyle.Haptic.selection()
                }

                progressHeader

                quickCreateTaskCard

                if visibleTaskSections.isEmpty {
                    EmptyStateView(
                        iconName: "checklist",
                        title: "All Caught Up!",
                        message: "There are no tasks matching your current filters. Take a break or create a new task below."
                    )
                    .padding(.top, 20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(Array(visibleTaskSections.enumerated()), id: \.offset) { _, section in
                                taskSection(title: section.title, tasks: section.tasks)
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
                    .padding(.horizontal, -20) // Negate parent padding
                    .contentMargins(20, for: .scrollContent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 116)
        }
        .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedAssigneeID == nil {
                selectedAssigneeID = appState.currentMembership?.id
            }
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(
                task: task,
                members: appState.familyMembers,
                onSave: { title, assigneeID, dueDate in
                    _ = appState.updateTask(
                        id: task.id,
                        title: title,
                        assigneeMemberID: assigneeID,
                        dueDate: dueDate
                    )
                    editingTask = nil
                },
                onDelete: {
                    appState.deleteTask(id: task.id)
                    editingTask = nil
                }
            )
        }
    }

    @ViewBuilder
    private var progressHeader: some View {
        if completionRate > 0 {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(AppStyle.Palette.progressTrack, lineWidth: 6)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(
                            LinearGradient(
                                colors: [AppStyle.Palette.progressStart, AppStyle.Palette.progressEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: completionRate)
                    
                    Text("\(Int(completionRate * 100))%")
                        .font(AppStyle.Typography.tiny.bold())
                        .foregroundStyle(AppStyle.Palette.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(completionRate == 1.0 ? "All Done!" : "Daily Progress")
                        .font(AppStyle.Typography.bodyStrong)
                        .foregroundStyle(AppStyle.Palette.textPrimary)
                    
                    Text(completionRate == 1.0 ? "You've completed all tasks for today." : "Keep it up, you're making great progress.")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .glassPanel(cornerRadius: AppStyle.Radius.card)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var quickCreateTaskCard: some View {
        SurfaceCard(title: "Add Task", iconAssetName: "Task") {
            VStack(spacing: 10) {
                TextField("Task title", text: $draftTaskTitle)
                    .glassInputField()

                TaskAssigneeSelector(
                    selection: $selectedAssigneeID,
                    members: appState.familyMembers
                )

                AppDateSelector(
                    selection: $draftDueDate,
                    title: "Due date",
                    iconName: "calendar.badge.clock",
                    tint: AppStyle.Palette.primary,
                    quickOptions: [.today, .tomorrow, .nextWeek]
                )

                AppTimeSelector(
                    selection: $draftDueDate,
                    title: "Due time",
                    tint: AppStyle.Palette.primary
                )

                Button("Create Task") {
                    appState.addTask(title: draftTaskTitle, assigneeMemberID: selectedAssigneeID, dueDate: draftDueDate)
                    draftTaskTitle = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(AppStyle.Palette.primary)
                .font(AppStyle.Typography.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func taskSection(title: String, tasks: [TaskRecord]) -> some View {
        SurfaceCard(title: title, iconAssetName: "Task", trailingText: "\(tasks.count)") {
            VStack(spacing: 8) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    TaskItemRow(
                        task: task,
                        assigneeName: appState.displayName(for: task.assigneeMemberID),
                        onToggle: {
                            appState.toggleTask(id: task.id)
                        },
                        onEdit: {
                            editingTask = task
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            AppStyle.Haptic.play(.medium)
                            appState.deleteTask(id: task.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            AppStyle.Haptic.play(.light)
                            appState.toggleTask(id: task.id)
                        } label: {
                            Label(task.isCompleted ? "Undo" : "Complete", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(task.isCompleted ? .gray : AppStyle.Palette.accent)
                    }
                    .contextMenu {
                        Button {
                            editingTask = task
                        } label: {
                            Label("Edit Task", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            appState.deleteTask(id: task.id)
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }

                    if index != tasks.count - 1 {
                        Divider().overlay(AppStyle.Palette.separator)
                    }
                }
            }
        }
    }
}

struct TaskAssigneeSelector: View {
    @Binding var selection: UUID?
    let members: [FamilyMembership]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Assignee", systemImage: "person.crop.circle.badge.checkmark")
                    .font(AppStyle.Typography.tiny)
                    .foregroundStyle(AppStyle.Palette.textSecondary)

                Spacer()

                Text(selectedName)
                    .font(AppStyle.Typography.tiny)
                    .foregroundStyle(AppStyle.Palette.primary)
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    unassignedChip

                    ForEach(members) { member in
                        memberChip(member)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppStyle.Palette.surface.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppStyle.Palette.glassHighlight.opacity(0.9), lineWidth: 1)
                )
        )
    }

    private var selectedName: String {
        guard let selection else { return "Unassigned" }
        return members.first(where: { $0.id == selection })?.displayName ?? "Unassigned"
    }

    private var unassignedChip: some View {
        Button {
            selection = nil
        } label: {
            chipContent(
                title: "Unassigned",
                subtitle: "No owner",
                isSelected: selection == nil
            ) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selection == nil ? Color.white : AppStyle.Palette.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func memberChip(_ member: FamilyMembership) -> some View {
        let isSelected = selection == member.id

        return Button {
            selection = member.id
        } label: {
            chipContent(
                title: member.displayName,
                subtitle: member.role.rawValue,
                isSelected: isSelected
            ) {
                Image(member.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white.opacity(0.86) : AppStyle.Palette.primary.opacity(0.14), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func chipContent<Avatar: View>(
        title: String,
        subtitle: String,
        isSelected: Bool,
        @ViewBuilder avatar: () -> Avatar
    ) -> some View {
        HStack(spacing: 9) {
            avatar()
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.20) : AppStyle.Palette.primarySoft.opacity(0.66))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(isSelected ? Color.white : AppStyle.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(AppStyle.Typography.tiny)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : AppStyle.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(width: 152, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? AppStyle.Palette.primary : AppStyle.Palette.surface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppStyle.Palette.primary.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
                )
        )
    }
}

private struct TaskEditorSheet: View {
    let task: TaskRecord
    let members: [FamilyMembership]
    let onSave: (String, UUID?, Date) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var assigneeID: UUID?
    @State private var dueDate: Date

    init(
        task: TaskRecord,
        members: [FamilyMembership],
        onSave: @escaping (String, UUID?, Date) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.task = task
        self.members = members
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: task.title)
        _assigneeID = State(initialValue: task.assigneeMemberID)
        _dueDate = State(initialValue: task.dueDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    TextField("Task title", text: $title)
                        .glassInputField()

                    TaskAssigneeSelector(selection: $assigneeID, members: members)

                    AppDateSelector(
                        selection: $dueDate,
                        title: "Due date",
                        iconName: "calendar.badge.clock",
                        tint: AppStyle.Palette.primary,
                        quickOptions: [.today, .tomorrow, .nextWeek]
                    )

                    AppTimeSelector(selection: $dueDate, title: "Due time", tint: AppStyle.Palette.primary)

                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .font(AppStyle.Typography.label)
                }
                .padding(20)
            }
            .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(title, assigneeID, dueDate)
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
        TaskBoardView()
            .environmentObject(AppState())
    }
}
