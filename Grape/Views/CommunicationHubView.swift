import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CommunicationHubView: View {
    @EnvironmentObject private var appState: AppState

    @State private var draftMessage = ""
    @State private var editingMessage: GroupMessage?
    @State private var actionMessage: GroupMessage?
    @State private var taskDraft: ChatTaskDraft?
    @State private var scheduleDraft: ChatScheduleDraft?

    private var messageGroups: [ChatDayGroup] {
        let calendar = Calendar.current
        var groups: [ChatDayGroup] = []

        for message in appState.groupMessages {
            let day = calendar.startOfDay(for: message.sentAt)
            if groups.last?.day == day {
                groups[groups.count - 1].messages.append(message)
            } else {
                groups.append(ChatDayGroup(day: day, messages: [message]))
            }
        }

        return groups
    }

    private var draftActions: [ChatQuickAction] {
        ChatQuickAction.detect(in: draftMessage)
    }

    private var displayedOnlineCount: Int {
        max(appState.onlineMemberCount, appState.currentMembership == nil ? 0 : 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)

            messagesView

            composer
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 116)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(AppStyle.Palette.separator)
                                .frame(height: 1)
                        }
                )
        }
        .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
        .navigationTitle("Family Chat")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingMessage) { message in
            ChatMessageEditor(message: message) { updatedText in
                _ = appState.updateGroupMessage(id: message.id, text: updatedText)
                editingMessage = nil
            }
        }
        .sheet(item: $actionMessage) { message in
            ChatMessageActionSheet(
                message: message,
                isMine: message.senderMemberID == appState.currentMembership?.id,
                isSaved: appState.isChatMessageSaved(message.id),
                canRecordExpense: FinanceTransactionDraftParser.amount(in: message.text) != nil,
                suggestedActions: ChatQuickAction.detect(in: message.text),
                onToggleSaved: {
                    appState.toggleSavedChatMessage(message)
                    actionMessage = nil
                },
                onEdit: {
                    actionMessage = nil
                    editingMessage = message
                },
                onCopy: {
                    copy(message.text)
                    actionMessage = nil
                },
                onRecall: {
                    appState.deleteGroupMessage(id: message.id)
                    actionMessage = nil
                },
                onCreateTask: {
                    actionMessage = nil
                    taskDraft = ChatTaskDraft(
                        title: ChatTaskDraftParser.title(from: message.text),
                        assigneeID: appState.currentMembership?.id,
                        dueDate: inferredDate(from: message.text)
                    )
                },
                onAddSchedule: {
                    actionMessage = nil
                    scheduleDraft = ChatScheduleDraft(
                        title: message.text.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: inferredDate(from: message.text)
                    )
                },
                onRecordExpense: {
                    perform(.expense, with: message.text, shouldClearDraft: false)
                    actionMessage = nil
                }
            )
            .presentationDetents([.height(330), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $scheduleDraft) { draft in
            ChatScheduleDraftSheet(draft: draft) { title, date in
                appState.addSchedule(title: title, subtitle: nil, date: date)
                scheduleDraft = nil
            }
        }
        .sheet(item: $taskDraft) { draft in
            ChatTaskDraftSheet(draft: draft, members: appState.familyMembers) { title, assigneeID, dueDate in
                appState.addTask(title: title, assigneeMemberID: assigneeID, dueDate: dueDate)
                taskDraft = nil
            }
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            AssetCircleIcon(assetName: "Communication", iconSize: 24, circleSize: 46, iconScale: 1.12)

            VStack(alignment: .leading, spacing: 3) {
                Text("Family Group")
                    .font(AppStyle.Typography.section)
                    .foregroundStyle(AppStyle.Palette.textPrimary)

                Text("\(displayedOnlineCount) online · \(appState.familyMembers.count) members")
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Circle()
                    .fill(AppStyle.Palette.accent)
                    .frame(width: 7, height: 7)
                Text("\(displayedOnlineCount) online")
                    .font(AppStyle.Typography.tiny)
                    .foregroundStyle(AppStyle.Palette.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppStyle.Palette.surface.opacity(0.82), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppStyle.Palette.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if appState.groupMessages.isEmpty {
                    emptyState
                        .padding(.horizontal, 24)
                        .padding(.top, 72)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(messageGroups) { group in
                            dateDivider(group.label)
                                .padding(.vertical, 8)

                            ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                                let previous = index > 0 ? group.messages[index - 1] : nil
                                let next = index < group.messages.count - 1 ? group.messages[index + 1] : nil
                                messageBubble(
                                    message,
                                    showsSender: shouldShowSender(for: message, previous: previous),
                                    isLastInRun: next?.senderMemberID != message.senderMemberID
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 18)
                }
            }
            .onAppear {
                scrollToLatest(using: proxy)
            }
            .onChange(of: appState.groupMessages.count) {
                scrollToLatest(using: proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppStyle.Palette.primary)
                .frame(width: 72, height: 72)
                .background(AppStyle.Palette.primarySoft.opacity(0.68), in: Circle())

            Text("No messages yet")
                .font(AppStyle.Typography.label)
                .foregroundStyle(AppStyle.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        VStack(spacing: 9) {
            if !draftActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(draftActions) { action in
                            Button {
                                handleDraftAction(action)
                            } label: {
                                Label(action.title, systemImage: action.systemImage)
                                    .font(AppStyle.Typography.tiny)
                                    .foregroundStyle(AppStyle.Palette.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(AppStyle.Palette.surface.opacity(0.88), in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(AppStyle.Palette.primary.opacity(0.10), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Type a message", text: $draftMessage, axis: .vertical)
                    .font(AppStyle.Typography.body)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(AppStyle.Palette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppStyle.Palette.primary.opacity(0.10), lineWidth: 1)
                    )
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit(sendDraftMessage)

                Button(action: sendDraftMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(
                                colors: [AppStyle.Palette.primary, AppStyle.Palette.primary.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.42 : 1)
            }
        }
    }

    private func dateDivider(_ title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(AppStyle.Palette.separator)
                .frame(height: 1)

            Text(title)
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)
                .lineLimit(1)

            Rectangle()
                .fill(AppStyle.Palette.separator)
                .frame(height: 1)
        }
    }

    private func messageBubble(_ message: GroupMessage, showsSender: Bool, isLastInRun: Bool) -> some View {
        let isMine = message.senderMemberID == appState.currentMembership?.id

        return HStack(alignment: .bottom, spacing: 7) {
            if isMine { Spacer(minLength: 84) }

            if !isMine {
                avatar(for: message, visible: isLastInRun)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if showsSender {
                    Text(message.senderName)
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                        .padding(.horizontal, 4)
                }

                VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(AppStyle.Typography.label)
                        .foregroundStyle(isMine ? .white : AppStyle.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if isLastInRun {
                        Text(message.sentAt, style: .time)
                            .font(AppStyle.Typography.tiny.monospacedDigit())
                            .foregroundStyle(isMine ? Color.white.opacity(0.76) : AppStyle.Palette.textSecondary)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .frame(maxWidth: messageMaxWidth, alignment: isMine ? .trailing : .leading)
                .background {
                    if isMine {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppStyle.Palette.primary,
                                        AppStyle.Palette.primary.opacity(0.86)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(AppStyle.Palette.surface.opacity(0.68))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(AppStyle.Palette.glassHighlight.opacity(0.78), lineWidth: 1)
                            )
                    }
                }
                .shadow(color: AppStyle.Palette.glassShadow.opacity(isMine ? 0.38 : 0.24), radius: 5, x: 0, y: 2)
            }
            .onLongPressGesture {
                actionMessage = message
            }

            if !isMine { Spacer(minLength: 84) }
        }
        .padding(.top, showsSender ? 5 : 0)
    }

    private var messageMaxWidth: CGFloat {
        return 250
    }

    private func avatar(for message: GroupMessage, visible: Bool) -> some View {
        Text(visible ? initials(from: message.senderName) : "")
            .font(AppStyle.Typography.tiny)
            .foregroundStyle(AppStyle.Palette.primary)
            .frame(width: 30, height: 30)
            .background(visible ? AppStyle.Palette.primarySoft.opacity(0.82) : Color.clear, in: Circle())
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        if letters.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(letters).uppercased()
    }

    private func shouldShowSender(for message: GroupMessage, previous: GroupMessage?) -> Bool {
        guard message.senderMemberID != appState.currentMembership?.id else { return false }
        return previous?.senderMemberID != message.senderMemberID
    }

    private func sendDraftMessage() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.sendGroupMessage(text: trimmed)
        draftMessage = ""
    }

    private func handleDraftAction(_ action: ChatQuickAction) {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch action {
        case .task:
            taskDraft = ChatTaskDraft(
                title: ChatTaskDraftParser.title(from: trimmed),
                assigneeID: appState.currentMembership?.id,
                dueDate: inferredDate(from: trimmed)
            )
        case .schedule:
            scheduleDraft = ChatScheduleDraft(title: trimmed, date: inferredDate(from: trimmed))
        case .expense:
            perform(.expense, with: trimmed, shouldClearDraft: true)
            return
        }

        draftMessage = ""
    }

    private func perform(_ action: ChatQuickAction, with text: String, shouldClearDraft: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch action {
        case .task:
            let taskTitle = ChatTaskDraftParser.title(from: trimmed)
            appState.addTask(
                title: taskTitle,
                assigneeMemberID: appState.currentMembership?.id,
                dueDate: inferredDate(from: trimmed)
            )
        case .schedule:
            appState.addSchedule(title: trimmed, subtitle: nil, date: inferredDate(from: trimmed))
        case .expense:
            guard let amount = FinanceTransactionDraftParser.amount(in: trimmed) else { return }
            let title = expenseTitle(from: trimmed)
            let suggestion = FinanceCategoryClassifier.suggestion(
                for: title,
                kind: .expense,
                amount: amount,
                history: appState.expenseTransactions
            )
            appState.addFinanceTransaction(
                title: title.isEmpty ? "Chat expense" : title,
                amount: amount,
                kind: .expense,
                category: suggestion.category
            )
        }

        if shouldClearDraft {
            draftMessage = ""
        }
    }

    private func expenseTitle(from text: String) -> String {
        text
            .replacingOccurrences(
                of: #"(?:A\$|\$)\s*\d+(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:,\d{3})*\.\d{1,2}"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferredDate(from text: String) -> Date {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let base: Date

        if lowercased.contains("next week") {
            base = calendar.date(byAdding: .day, value: 7, to: .now) ?? .now
        } else if lowercased.contains("tomorrow") {
            base = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        } else {
            base = .now
        }

        if lowercased.contains("tonight") {
            return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: base) ?? base
        }
        if lowercased.contains("morning") {
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
        }
        return base
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let last = appState.groupMessages.last else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private struct ChatDayGroup: Identifiable {
    let day: Date
    var messages: [GroupMessage]

    var id: Date { day }

    var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

private struct ChatTaskDraft: Identifiable {
    let id = UUID()
    let title: String
    let assigneeID: UUID?
    let dueDate: Date
}

private struct ChatScheduleDraft: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
}

private enum ChatQuickAction: String, Identifiable {
    case task
    case schedule
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: return "Add as task"
        case .schedule: return "Add to calendar"
        case .expense: return "Record in wallet"
        }
    }

    var systemImage: String {
        switch self {
        case .task: return "checklist"
        case .schedule: return "calendar.badge.plus"
        case .expense: return "wallet.pass.fill"
        }
    }

    static func detect(in text: String) -> [ChatQuickAction] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        guard !trimmed.isEmpty else { return [] }

        var actions: [ChatQuickAction] = []
        if FinanceTransactionDraftParser.amount(in: trimmed) != nil {
            actions.append(.expense)
        }
        if normalized.contains("tomorrow")
            || normalized.contains("tonight")
            || normalized.contains("next week")
            || normalized.contains("schedule")
            || normalized.contains("calendar") {
            actions.append(.schedule)
        }
        if normalized.contains("remember")
            || normalized.contains("buy")
            || normalized.contains("pick up")
            || normalized.contains("todo")
            || normalized.contains("task") {
            actions.append(.task)
        }

        return actions
    }
}

private enum ChatTaskDraftParser {
    static func title(from text: String) -> String {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleaned = original

        let replacements = [
            #"(?i)^\s*(please\s+)?(add|create|make)\s+(a\s+)?(new\s+)?(task|todo)(\s+to)?[:\-]?\s*"#,
            #"(?i)^\s*(task|todo)[:\-]?\s*"#,
            #"(?i)^\s*(remember|remind me)\s+(to\s+)?"#,
            #"(?i)\s+(task|todo)\s*[.!?]?\s*$"#,
            #"(?i)\s+(tomorrow|tonight|next week)\s*[.!?]?\s*$"#
        ]

        for pattern in replacements {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        cleaned = cleaned
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? original : cleaned
    }
}

private struct ChatMessageActionSheet: View {
    let message: GroupMessage
    let isMine: Bool
    let isSaved: Bool
    let canRecordExpense: Bool
    let suggestedActions: [ChatQuickAction]
    let onToggleSaved: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onRecall: () -> Void
    let onCreateTask: () -> Void
    let onAddSchedule: () -> Void
    let onRecordExpense: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(AppStyle.Palette.textSecondary.opacity(0.22))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)

            preview
            primaryActions
            secondaryActions
        }
        .padding(20)
        .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
    }

    private var preview: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(initials(from: message.senderName))
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.primary)
                .frame(width: 32, height: 32)
                .background(AppStyle.Palette.primarySoft.opacity(0.82), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(message.senderName)
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)

                Text(message.text)
                    .font(AppStyle.Typography.label)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppStyle.Palette.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppStyle.Palette.glassHighlight.opacity(0.82), lineWidth: 1)
        )
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            actionTile(
                title: "Task",
                systemImage: "checklist",
                highlighted: suggestedActions.contains(.task),
                action: onCreateTask
            )

            actionTile(
                title: "Schedule",
                systemImage: "calendar.badge.plus",
                highlighted: suggestedActions.contains(.schedule),
                action: onAddSchedule
            )

            if canRecordExpense {
                actionTile(
                    title: "Wallet",
                    systemImage: "wallet.pass.fill",
                    highlighted: suggestedActions.contains(.expense),
                    action: onRecordExpense
                )
            }
        }
    }

    private var secondaryActions: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            if isMine {
                compactButton(title: "Edit", systemImage: "pencil", action: onEdit)
            }
            compactButton(
                title: isSaved ? "Unsave" : "Save",
                systemImage: isSaved ? "bookmark.slash" : "bookmark",
                action: onToggleSaved
            )
            compactButton(title: "Copy", systemImage: "doc.on.doc", action: onCopy)
            if isMine {
                compactButton(title: "Recall", systemImage: "arrow.uturn.backward.circle", tint: .red, action: onRecall)
            }
        }
    }

    private func actionTile(
        title: String,
        systemImage: String,
        tint: Color = AppStyle.Palette.primary,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(highlighted ? Color.white : tint)
                    .frame(width: 40, height: 40)
                    .background(highlighted ? tint : tint.opacity(0.12), in: Circle())

                Text(title)
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(highlighted ? AppStyle.Palette.primarySoft.opacity(0.72) : AppStyle.Palette.surface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(tint.opacity(highlighted ? 0.18 : 0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func compactButton(
        title: String,
        systemImage: String,
        tint: Color = AppStyle.Palette.primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(AppStyle.Typography.caption)
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tint.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(name.prefix(1)).uppercased() : String(letters).uppercased()
    }
}

private struct ChatScheduleDraftSheet: View {
    let draft: ChatScheduleDraft
    let onSave: (String, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date

    init(draft: ChatScheduleDraft, onSave: @escaping (String, Date) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _title = State(initialValue: draft.title)
        _date = State(initialValue: draft.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    TextField("Title", text: $title)
                        .glassInputField()

                    AppDateSelector(
                        selection: $date,
                        title: "Date",
                        iconName: "calendar",
                        tint: AppStyle.Palette.primary,
                        quickOptions: [.today, .tomorrow, .nextWeek],
                        startsExpanded: true
                    )

                    AppTimeSelector(selection: $date, title: "Time", tint: AppStyle.Palette.primary)
                }
                .padding(20)
            }
            .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
            .navigationTitle("Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(title, date)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ChatTaskDraftSheet: View {
    let draft: ChatTaskDraft
    let members: [FamilyMembership]
    let onSave: (String, UUID?, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var assigneeID: UUID?
    @State private var dueDate: Date

    init(
        draft: ChatTaskDraft,
        members: [FamilyMembership],
        onSave: @escaping (String, UUID?, Date) -> Void
    ) {
        self.draft = draft
        self.members = members
        self.onSave = onSave
        _title = State(initialValue: draft.title)
        _assigneeID = State(initialValue: draft.assigneeID)
        _dueDate = State(initialValue: draft.dueDate)
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
                        quickOptions: [.today, .tomorrow, .nextWeek],
                        startsExpanded: true
                    )

                    AppTimeSelector(selection: $dueDate, title: "Due time", tint: AppStyle.Palette.primary)
                }
                .padding(20)
            }
            .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
            .navigationTitle("Create Task")
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

private struct ChatMessageEditor: View {
    let message: GroupMessage
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String

    init(message: GroupMessage, onSave: @escaping (String) -> Void) {
        self.message = message
        self.onSave = onSave
        _draftText = State(initialValue: message.text)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField("Message", text: $draftText, axis: .vertical)
                    .lineLimit(3...8)
                    .glassInputField()

                Text("Changes sync with the family chat.")
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)

                Spacer()
            }
            .padding(20)
            .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draftText)
                        dismiss()
                    }
                    .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CommunicationHubView()
            .environmentObject(AppState())
    }
}
