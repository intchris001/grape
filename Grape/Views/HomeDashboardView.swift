import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showFamilyHub = false
    @State private var showProfileSettings = false

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    private var todayTasks: [TaskRecord] {
        appState.tasks.filter { Calendar.current.isDateInToday($0.dueDate) }
    }

    private var completedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    private var completionProgress: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(todayTasks.count)
    }

    private var todaySchedule: [ScheduleEntry] {
        appState.scheduleEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var greetingName: String {
        appState.currentMembership?.displayName ?? appState.currentUser?.username ?? "User"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                greetingHeader
                progressCard
                familyCard

                if todaySchedule.isEmpty {
                    SurfaceCard(title: "Schedule", iconAssetName: "Timetable") {
                        Text("No schedule for today")
                            .font(AppStyle.Typography.label)
                            .foregroundStyle(AppStyle.Palette.textSecondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Schedule")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(Array(todaySchedule.enumerated()), id: \.element.id) { index, item in
                                    SurfaceCard(title: "Event", iconAssetName: "Timetable") {
                                        ScheduleTimelineRow(item: item)
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

                if todayTasks.isEmpty {
                    SurfaceCard(title: "Tasks", iconAssetName: "Task") {
                        Text("No tasks due today")
                            .font(AppStyle.Typography.label)
                            .foregroundStyle(AppStyle.Palette.textSecondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Tasks")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(Array(todayTasks.enumerated()), id: \.element.id) { index, task in
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 116)
        }
        .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFamilyHub = true
                } label: {
                    AssetCircleIcon(assetName: "One Family", iconSize: 18, circleSize: 36)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showProfileSettings = true
                } label: {
                    if let avatar = appState.currentMembership?.avatarAssetName {
                        Image(avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppStyle.Palette.primary.opacity(0.2), lineWidth: 1))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppStyle.Palette.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showProfileSettings) {
            ProfileSettingsView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFamilyHub) {
            NavigationStack {
                OneFamilyHubView()
                    .environmentObject(appState)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var greetingHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(timeGreeting),")
                    .font(AppStyle.Typography.titleM)
                    .foregroundStyle(AppStyle.Palette.textSecondary)

                Text(greetingName)
                    .font(AppStyle.Typography.titleXL)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppStyle.Palette.primarySoft.opacity(0.7))
                    .frame(width: 112, height: 112)

                Image("AppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .scaleEffect(1.08)
            }
        }
        .padding(20)
        .glassPanel(cornerRadius: 24, strokeOpacity: 0.88)
    }

    private var progressCard: some View {
        SurfaceCard(title: "Progress", iconAssetName: "Task") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(completedCount)/\(todayTasks.count)")
                        .font(AppStyle.Typography.titleXL)
                        .foregroundStyle(AppStyle.Palette.textPrimary)

                    Text("tasks completed")
                        .font(AppStyle.Typography.titleM)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppStyle.Palette.progressTrack)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppStyle.Palette.primary,
                                        AppStyle.Palette.primary.opacity(0.82),
                                        AppStyle.Palette.accent
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * completionProgress)
                    }
                }
                .frame(height: 14)
            }
        }
    }

    private var familyCard: some View {
        SurfaceCard(title: "Family", iconAssetName: "One Family", trailingText: appState.currentMembership?.role.rawValue ?? "-") {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(appState.familyMembers) { member in
                        FamilyMemberAvatar(member: member)
                    }
                }
            }
            .onTapGesture {
                showFamilyHub = true
            }
        }
    }
}

private struct SectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(AppStyle.Typography.section)
            .foregroundStyle(AppStyle.Palette.textPrimary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack {
        HomeDashboardView()
            .environmentObject(AppState())
    }
}
