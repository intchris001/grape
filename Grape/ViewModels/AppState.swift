import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum CloudSyncStatus: Equatable {
    case idle
    case syncing
    case live(Date)
    case failed(String)

    var message: String {
        switch self {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing"
        case .live:
            return "Live"
        case .failed(let message):
            return message
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var snapshot: AppDataSnapshot
    @Published private(set) var syncStatus: CloudSyncStatus = .idle
    @Published private(set) var onlineMemberIDs: Set<UUID> = []

    private let store: LocalJSONStore
    private var hasBootstrappedCloudSync = false
    private var lastBootstrappedSyncKey: String?
    private var activeRealtimeFamilyID: String?
    private var activePresenceKey: String?
    private var presenceHeartbeatTask: Task<Void, Never>?

    init(store: LocalJSONStore? = nil) {
        self.store = store ?? LocalJSONStore()
        self.snapshot = self.store.load(AppDataSnapshot.self) ?? SeedData.makeInitialSnapshot()
        ensureDemoAccounts()
        self.store.save(snapshot)
        Task {
            await syncLocalSessionFromFirebaseAuth()
            await bootstrapCloudSyncIfNeeded()
            await recoverMissingFamilyIfNeeded()
            startRealtimeSyncIfNeeded()
        }
    }

    var currentUser: UserAccount? {
        guard let id = snapshot.currentUserID else { return nil }
        return snapshot.users.first(where: { $0.id == id })
    }

    var currentFamily: FamilyGroup? {
        guard let familyID = currentUser?.currentFamilyID else { return nil }
        return snapshot.families.first(where: { $0.id == familyID })
    }

    var currentMembership: FamilyMembership? {
        guard let userID = currentUser?.id, let familyID = currentFamily?.id else { return nil }
        return snapshot.memberships.first { $0.userID == userID && $0.familyID == familyID }
    }

    var currentUserCanManageMembers: Bool {
        currentMembership?.role.canManageMembers == true
    }

    var familyMembers: [FamilyMembership] {
        guard let familyID = currentFamily?.id else { return [] }
        return snapshot.memberships
            .filter { $0.familyID == familyID }
            .sorted { $0.joinedAt < $1.joinedAt }
    }

    var onlineMemberCount: Int {
        onlineMemberIDs.count
    }

    var pendingJoinRequests: [FamilyJoinRequest] {
        guard let familyID = currentFamily?.id else { return [] }
        return snapshot.joinRequests
            .filter { $0.familyID == familyID }
            .sorted { $0.requestedAt < $1.requestedAt }
    }

    var currentUserPendingJoinRequest: FamilyJoinRequest? {
        guard let userID = currentUser?.id else { return nil }
        return snapshot.joinRequests
            .filter { $0.userID == userID }
            .sorted { $0.requestedAt > $1.requestedAt }
            .first
    }

    var tasks: [TaskRecord] {
        guard let familyID = currentFamily?.id else { return [] }
        return snapshot.tasks
            .filter { $0.familyID == familyID }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var scheduleEntries: [ScheduleEntry] {
        guard let familyID = currentFamily?.id else { return [] }
        return snapshot.scheduleEntries
            .filter { $0.familyID == familyID }
            .sorted { $0.date < $1.date }
    }

    var groupMessages: [GroupMessage] {
        guard let familyID = currentFamily?.id else { return [] }
        return snapshot.groupMessages
            .filter { $0.familyID == familyID }
            .sorted { $0.sentAt < $1.sentAt }
    }

    var savedChatMessages: [SavedChatMessage] {
        guard let familyID = currentFamily?.id else { return [] }
        return snapshot.savedChatMessages
            .filter { $0.familyID == familyID }
            .sorted { $0.savedAt > $1.savedAt }
    }

    var expenseTransactions: [ExpenseTransaction] {
        guard let familyID = currentFamily?.id else { return [] }
        return snapshot.expenseTransactions
            .filter { $0.familyID == familyID }
            .sorted { $0.date > $1.date }
    }

    var currentSavingsGoal: SavingsGoal? {
        guard let familyID = currentFamily?.id else { return nil }
        return snapshot.savingsGoals
            .filter { $0.familyID == familyID }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func register(username: String, email: String, password: String) async -> String? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else { return "Username is required." }
        guard !normalizedEmail.isEmpty else { return "Email is required." }
        guard password.count >= 6 else { return "Password must be at least 6 characters." }

#if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
            syncOrCreateLocalUser(
                firebaseUID: result.user.uid,
                email: normalizedEmail,
                username: trimmedUsername
            )
            persist()
            await bootstrapCloudSyncIfNeeded()
            await recoverMissingFamilyIfNeeded()
            startRealtimeSyncIfNeeded()
            return nil
        } catch {
            return mapFirebaseAuthError(error)
        }
#else
        guard !snapshot.users.contains(where: { $0.email.lowercased() == normalizedEmail }) else {
            return "Email already exists."
        }

        let user = UserAccount(
            id: UUID(),
            username: trimmedUsername,
            email: normalizedEmail,
            password: "",
            firebaseUID: nil,
            currentFamilyID: nil
        )
        snapshot.users.append(user)
        snapshot.currentUserID = user.id
        persist()
        return nil
#endif
    }

    func login(email: String, password: String) async -> String? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

#if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: normalized, password: password)
            let fallbackUsername = normalized.split(separator: "@").first.map(String.init) ?? "User"
            syncOrCreateLocalUser(
                firebaseUID: result.user.uid,
                email: normalized,
                username: fallbackUsername
            )
            await loadAndApplyRemoteCurrentFamilyID(firebaseUID: result.user.uid)
            persist()
            await bootstrapCloudSyncIfNeeded()
            await recoverMissingFamilyIfNeeded()
            startRealtimeSyncIfNeeded()
            return nil
        } catch {
            return mapFirebaseAuthError(error)
        }
#else
        guard let user = snapshot.users.first(where: { $0.email.lowercased() == normalized && $0.password == password }) else {
            return "Invalid email or password."
        }
        snapshot.currentUserID = user.id
        persist()
        return nil
#endif
    }

    func logout() {
        snapshot.currentUserID = nil
        lastBootstrappedSyncKey = nil
        activeRealtimeFamilyID = nil
        syncStatus = .idle
#if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            print("Firebase sign out failed: \(error.localizedDescription)")
        }
#endif
        Task { await FirebaseSyncService.shared.stopAllFamilyListeners() }
        persist()
    }

    func resetToSeedData() {
        store.clear()
        snapshot = SeedData.makeInitialSnapshot()
        ensureDemoAccounts()
        activeRealtimeFamilyID = nil
        syncStatus = .idle
        Task { await FirebaseSyncService.shared.stopAllFamilyListeners() }
        persist()
    }

    func createFamily(name: String, displayName: String, avatar: String) -> String? {
        guard let user = currentUser else { return "Please login first." }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return "Family name is required." }
        guard !trimmedDisplay.isEmpty else { return "Display name is required." }

        let familyID = UUID()
        let inviteCode = String(familyID.uuidString.prefix(6)).uppercased()

        let family = FamilyGroup(
            id: familyID,
            name: trimmedName,
            inviteCode: inviteCode,
            createdBy: user.id,
            createdAt: .now
        )

        let member = FamilyMembership(
            id: UUID(),
            familyID: familyID,
            userID: user.id,
            displayName: trimmedDisplay,
            role: .owner,
            avatarAssetName: avatar,
            joinedAt: .now
        )

        snapshot.families.append(family)
        snapshot.memberships.append(member)
        updateCurrentUserFamily(familyID)
        seedFirstFamilyContent(
            familyID: familyID,
            inviteCode: inviteCode,
            ownerMemberID: member.id,
            ownerName: trimmedDisplay
        )
        persist()
        return nil
    }

    func joinFamily(inviteCode: String, displayName: String, role: FamilyRole, avatar: String) async -> String? {
        guard let user = currentUser else { return "Please login first." }
        let normalizedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCode.isEmpty else { return "Family ID is required." }
        guard !trimmedDisplay.isEmpty else { return "Display name is required." }

        let family: FamilyGroup
        if let localFamily = snapshot.families.first(where: { $0.inviteCode == normalizedCode }) {
            family = localFamily
        } else if let remoteFamilyState = await FirebaseSyncService.shared.loadFamilyState(inviteCode: normalizedCode) {
            applyFamilyCloudState(remoteFamilyState)
            ensureDemoAccounts()
            store.save(snapshot)
            family = remoteFamilyState.family
        } else {
            return "Family ID not found."
        }

        if snapshot.memberships.contains(where: { $0.userID == user.id && $0.familyID == family.id }) {
            updateCurrentUserFamily(family.id)
            persist(uploadFamilyID: family.id)
            return nil
        }

        if snapshot.joinRequests.contains(where: { $0.userID == user.id && $0.familyID == family.id }) {
            return "Join request already sent. Please wait for approval."
        }

        let request = FamilyJoinRequest(
            id: UUID(),
            familyID: family.id,
            userID: user.id,
            displayName: trimmedDisplay,
            requestedRole: role,
            avatarAssetName: avatar,
            requestedAt: .now
        )
        snapshot.joinRequests.append(request)
        persist(uploadFamilyID: family.id)
        return "Join request sent. Waiting for owner/admin approval."
    }

    func cancelCurrentJoinRequest() -> String? {
        guard let requestID = currentUserPendingJoinRequest?.id,
              let index = snapshot.joinRequests.firstIndex(where: { $0.id == requestID }) else {
            return "No pending join request found."
        }
        let familyID = snapshot.joinRequests[index].familyID
        snapshot.joinRequests.remove(at: index)
        persist(uploadFamilyID: familyID)
        return nil
    }

    func family(for request: FamilyJoinRequest) -> FamilyGroup? {
        snapshot.families.first { $0.id == request.familyID }
    }

    func approveJoinRequest(requestID: UUID) -> String? {
        guard currentUserCanManageMembers else { return "Only owner/admin can approve requests." }
        guard let index = snapshot.joinRequests.firstIndex(where: { $0.id == requestID }) else {
            return "Request not found."
        }

        let request = snapshot.joinRequests[index]
        let member = FamilyMembership(
            id: UUID(),
            familyID: request.familyID,
            userID: request.userID,
            displayName: request.displayName,
            role: request.requestedRole,
            avatarAssetName: request.avatarAssetName,
            joinedAt: .now
        )
        snapshot.memberships.append(member)
        snapshot.joinRequests.remove(at: index)
        updateUserFamily(userID: request.userID, familyID: request.familyID)
        syncFamilySelectionToCloud(userID: request.userID, familyID: request.familyID)
        persist()
        return nil
    }

    func rejectJoinRequest(requestID: UUID) -> String? {
        guard currentUserCanManageMembers else { return "Only owner/admin can reject requests." }
        guard let index = snapshot.joinRequests.firstIndex(where: { $0.id == requestID }) else {
            return "Request not found."
        }
        snapshot.joinRequests.remove(at: index)
        persist()
        return nil
    }

    func updateMemberRole(memberID: UUID, to role: FamilyRole) -> String? {
        guard currentUserCanManageMembers else { return "Only owner/admin can manage roles." }
        guard let currentMember = currentMembership,
              let targetIndex = snapshot.memberships.firstIndex(where: { $0.id == memberID }) else {
            return "Member not found."
        }

        guard currentMember.role == .owner || role != .owner else {
            return "Only owner can assign owner role."
        }

        let target = snapshot.memberships[targetIndex]
        let sameFamilyOwners = snapshot.memberships.filter { $0.familyID == target.familyID && $0.role == .owner }

        if target.role == .owner && role != .owner && sameFamilyOwners.count <= 1 {
            return "At least one Owner must remain in the family."
        }

        snapshot.memberships[targetIndex].role = role
        persist()
        return nil
    }

    func updateCurrentUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Username cannot be empty." }
        guard let userID = currentUser?.id,
              let index = snapshot.users.firstIndex(where: { $0.id == userID }) else {
            return "User not found."
        }
        snapshot.users[index].username = trimmed
        persist(uploadFamilyID: currentFamily?.id)
        return nil
    }

    func updateCurrentDisplayName(_ displayName: String) -> String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Display name cannot be empty." }
        guard let memberID = currentMembership?.id,
              let index = snapshot.memberships.firstIndex(where: { $0.id == memberID }) else {
            return "Membership not found."
        }

        let familyID = snapshot.memberships[index].familyID
        snapshot.memberships[index].displayName = trimmed

        for i in snapshot.groupMessages.indices where snapshot.groupMessages[i].familyID == familyID && snapshot.groupMessages[i].senderMemberID == memberID {
            snapshot.groupMessages[i].senderName = trimmed
        }

        persist(uploadFamilyID: familyID)
        return nil
    }

    func removeMember(memberID: UUID) -> String? {
        guard currentUserCanManageMembers else { return "Only owner/admin can remove members." }
        guard let member = snapshot.memberships.first(where: { $0.id == memberID }) else { return "Member not found." }

        if member.userID == currentUser?.id {
            return "You cannot remove yourself."
        }

        snapshot.memberships.removeAll { $0.id == memberID }
        syncFamilySelectionToCloud(userID: member.userID, familyID: nil)
        persist()
        return nil
    }

    func addTask(title: String, assigneeMemberID: UUID?, dueDate: Date) {
        guard let user = currentUser, let family = currentFamily else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        snapshot.tasks.append(
            TaskRecord(
                id: UUID(),
                familyID: family.id,
                title: trimmed,
                assigneeMemberID: assigneeMemberID,
                dueDate: dueDate,
                isCompleted: false,
                createdByUserID: user.id
            )
        )
        persist()
    }

    func toggleTask(id: UUID) {
        guard let index = snapshot.tasks.firstIndex(where: { $0.id == id }) else { return }
        let familyID = snapshot.tasks[index].familyID
        snapshot.tasks[index].isCompleted.toggle()
        persist(uploadFamilyID: familyID)
    }

    func updateTask(id: UUID, title: String, assigneeMemberID: UUID?, dueDate: Date) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Task title cannot be empty." }
        guard let index = snapshot.tasks.firstIndex(where: { $0.id == id }) else {
            return "Task not found."
        }

        snapshot.tasks[index].title = trimmed
        snapshot.tasks[index].assigneeMemberID = assigneeMemberID
        snapshot.tasks[index].dueDate = dueDate
        persist(uploadFamilyID: snapshot.tasks[index].familyID)
        return nil
    }

    func deleteTask(id: UUID) {
        guard let task = snapshot.tasks.first(where: { $0.id == id }) else { return }
        snapshot.tasks.removeAll { $0.id == id }
        persist(uploadFamilyID: task.familyID)
    }

    func addSchedule(title: String, subtitle: String?, date: Date) {
        guard let family = currentFamily else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        snapshot.scheduleEntries.append(
            ScheduleEntry(id: UUID(), familyID: family.id, date: date, title: trimmed, subtitle: subtitle)
        )
        persist()
    }

    func updateSchedule(id: UUID, title: String, subtitle: String?, date: Date) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Schedule title cannot be empty." }
        guard let index = snapshot.scheduleEntries.firstIndex(where: { $0.id == id }) else {
            return "Schedule not found."
        }

        snapshot.scheduleEntries[index].title = trimmed
        snapshot.scheduleEntries[index].subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.scheduleEntries[index].date = date
        persist(uploadFamilyID: snapshot.scheduleEntries[index].familyID)
        return nil
    }

    func deleteSchedule(id: UUID) {
        guard let entry = snapshot.scheduleEntries.first(where: { $0.id == id }) else { return }
        snapshot.scheduleEntries.removeAll { $0.id == id }
        persist(uploadFamilyID: entry.familyID)
    }

    func sendGroupMessage(text: String) {
        guard let member = currentMembership, let family = currentFamily else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        snapshot.groupMessages.append(
            GroupMessage(
                id: UUID(),
                familyID: family.id,
                senderMemberID: member.id,
                senderName: member.displayName,
                text: trimmed,
                sentAt: .now
            )
        )
        persist()
    }

    func updateGroupMessage(id: UUID, text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Message cannot be empty." }
        guard let index = snapshot.groupMessages.firstIndex(where: { $0.id == id }) else {
            return "Message not found."
        }
        guard snapshot.groupMessages[index].senderMemberID == currentMembership?.id else {
            return "Only your own messages can be edited."
        }

        snapshot.groupMessages[index].text = trimmed
        persist(uploadFamilyID: snapshot.groupMessages[index].familyID)
        return nil
    }

    func deleteGroupMessage(id: UUID) {
        guard let message = snapshot.groupMessages.first(where: { $0.id == id }) else { return }
        guard message.senderMemberID == currentMembership?.id else { return }
        snapshot.groupMessages.removeAll { $0.id == id }
        persist(uploadFamilyID: message.familyID)
    }

    func isChatMessageSaved(_ messageID: UUID) -> Bool {
        guard let memberID = currentMembership?.id else { return false }
        return snapshot.savedChatMessages.contains {
            $0.messageID == messageID && $0.savedByMemberID == memberID
        }
    }

    func toggleSavedChatMessage(_ message: GroupMessage) {
        guard let memberID = currentMembership?.id else { return }
        if let existing = snapshot.savedChatMessages.first(where: {
            $0.messageID == message.id && $0.savedByMemberID == memberID
        }) {
            snapshot.savedChatMessages.removeAll { $0.id == existing.id }
        } else {
            snapshot.savedChatMessages.append(
                SavedChatMessage(
                    id: UUID(),
                    familyID: message.familyID,
                    messageID: message.id,
                    savedByMemberID: memberID,
                    senderName: message.senderName,
                    text: message.text,
                    messageSentAt: message.sentAt,
                    savedAt: .now
                )
            )
        }
        persist(uploadFamilyID: message.familyID)
    }

    func deleteSavedChatMessage(id: UUID) {
        guard let saved = snapshot.savedChatMessages.first(where: { $0.id == id }) else { return }
        snapshot.savedChatMessages.removeAll { $0.id == id }
        persist(uploadFamilyID: saved.familyID)
    }

    func addExpense(title: String, amount: Double, date: Date = .now) {
        addFinanceTransaction(
            title: title,
            amount: abs(amount),
            kind: amount > 0 ? .income : .expense,
            category: amount > 0 ? .income : .other,
            date: date
        )
    }

    func addFinanceTransaction(
        title: String,
        amount: Double,
        kind: FinancialTransactionKind,
        category: FinancialCategory,
        date: Date = .now
    ) {
        guard let family = currentFamily else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0 else { return }

        snapshot.expenseTransactions.append(
            ExpenseTransaction(
                id: UUID(),
                familyID: family.id,
                title: trimmed,
                date: date,
                amount: amount,
                kind: kind,
                category: category
            )
        )
        persist()
    }

    func updateFinanceTransaction(
        id: UUID,
        title: String,
        amount: Double,
        kind: FinancialTransactionKind,
        category: FinancialCategory,
        date: Date
    ) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Transaction title cannot be empty." }
        guard amount > 0 else { return "Amount must be greater than zero." }
        guard let index = snapshot.expenseTransactions.firstIndex(where: { $0.id == id }) else {
            return "Transaction not found."
        }

        snapshot.expenseTransactions[index].title = trimmed
        snapshot.expenseTransactions[index].amount = amount
        snapshot.expenseTransactions[index].kind = kind
        snapshot.expenseTransactions[index].category = category
        snapshot.expenseTransactions[index].date = date
        persist(uploadFamilyID: snapshot.expenseTransactions[index].familyID)
        return nil
    }

    func deleteFinanceTransaction(id: UUID) {
        guard let transaction = snapshot.expenseTransactions.first(where: { $0.id == id }) else { return }
        snapshot.expenseTransactions.removeAll { $0.id == id }
        persist(uploadFamilyID: transaction.familyID)
    }

    func setSavingsGoal(title: String, targetAmount: Double, currentAmount: Double, targetDate: Date? = nil) {
        guard let family = currentFamily else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, targetAmount > 0 else { return }

        if let index = snapshot.savingsGoals.firstIndex(where: { $0.familyID == family.id }) {
            snapshot.savingsGoals[index].title = trimmed
            snapshot.savingsGoals[index].targetAmount = targetAmount
            snapshot.savingsGoals[index].currentAmount = max(0, currentAmount)
            snapshot.savingsGoals[index].targetDate = targetDate
            snapshot.savingsGoals[index].updatedAt = .now
        } else {
            snapshot.savingsGoals.append(
                SavingsGoal(
                    id: UUID(),
                    familyID: family.id,
                    title: trimmed,
                    targetAmount: targetAmount,
                    currentAmount: max(0, currentAmount),
                    targetDate: targetDate,
                    updatedAt: .now
                )
            )
        }
        persist()
    }

    func displayName(for memberID: UUID?) -> String {
        guard let memberID else { return "Unassigned" }
        return familyMembers.first(where: { $0.id == memberID })?.displayName ?? "Unknown"
    }

    private func seedFirstFamilyContent(familyID: UUID, inviteCode: String, ownerMemberID: UUID, ownerName: String) {
        let now = Date.now

        snapshot.groupMessages.append(
            GroupMessage(
                id: UUID(),
                familyID: familyID,
                senderMemberID: ownerMemberID,
                senderName: ownerName,
                text: "Family created. Invite members with Family ID: \(inviteCode)",
                sentAt: now
            )
        )
    }

    private func updateCurrentUserFamily(_ familyID: UUID) {
        guard let userID = currentUser?.id,
              let index = snapshot.users.firstIndex(where: { $0.id == userID }) else { return }
        snapshot.users[index].currentFamilyID = familyID
        Task { await syncCurrentUserFamilySelectionToCloud() }
    }

    private func updateUserFamily(userID: UUID, familyID: UUID) {
        guard let index = snapshot.users.firstIndex(where: { $0.id == userID }) else { return }
        snapshot.users[index].currentFamilyID = familyID
    }

    private func syncFamilySelectionToCloud(userID: UUID, familyID: UUID?) {
        guard let firebaseUID = snapshot.users.first(where: { $0.id == userID })?.firebaseUID else { return }
        Task {
            await FirebaseSyncService.shared.saveCurrentFamilyID(familyID?.uuidString, for: firebaseUID)
        }
    }

    private func ensureDemoAccounts() {
        for account in SeedData.demoAccounts {
            if !snapshot.users.contains(where: { $0.email.lowercased() == account.email.lowercased() }) {
                snapshot.users.append(account)
            }
        }
    }

    func provisionFirebaseDemoAccounts() async -> String {
#if canImport(FirebaseAuth)
        let accounts = SeedData.demoAccounts.map { ($0.username, $0.email.lowercased(), "123456") }
        var created = 0
        var existing = 0
        var conflict = 0

        for account in accounts {
            do {
                _ = try await Auth.auth().signIn(withEmail: account.1, password: account.2)
                existing += 1
            } catch {
                let code = AuthErrorCode(rawValue: (error as NSError).code)

                do {
                    _ = try await Auth.auth().createUser(withEmail: account.1, password: account.2)
                    created += 1
                } catch {
                    let createCode = AuthErrorCode(rawValue: (error as NSError).code)
                    if code == .wrongPassword || createCode == .emailAlreadyInUse {
                        conflict += 1
                    } else {
                        conflict += 1
                    }
                }
            }

            do {
                try Auth.auth().signOut()
            } catch {
                print("Firebase sign out failed during demo account provisioning: \(error.localizedDescription)")
            }
        }

        snapshot.currentUserID = nil
        store.save(snapshot)

        if conflict == 0 {
            return "Demo accounts ready. Created \(created), existing \(existing)."
        }
        return "Demo accounts partially ready. Created \(created), existing \(existing), conflicts \(conflict) (likely same email with different password)."
#else
        return "FirebaseAuth package is missing."
#endif
    }

    private func persist(uploadFamilyID: UUID? = nil) {
        store.save(snapshot)
        Task { await syncCurrentUserFamilySelectionToCloud() }

        var familyIDs = Set<UUID>()
        if let currentFamilyID = currentFamily?.id {
            familyIDs.insert(currentFamilyID)
        }
        if let uploadFamilyID {
            familyIDs.insert(uploadFamilyID)
        }

        for familyID in familyIDs {
            queueFamilyUpload(familyID: familyID)
        }

        startRealtimeSyncIfNeeded()
    }

    private func queueFamilyUpload(familyID: UUID) {
        guard let familyState = makeFamilyCloudState(for: familyID) else { return }
        syncStatus = .syncing
        Task {
            let didSucceed = await FirebaseSyncService.shared.queueUploadFamily(
                state: familyState,
                familyID: familyID.uuidString
            )
            await MainActor.run {
                self.syncStatus = didSucceed ? .live(.now) : .failed("Sync failed")
            }
        }
    }

    private func startRealtimeSyncIfNeeded() {
        let familyID = currentFamily?.id ?? currentUserPendingJoinRequest?.familyID
        guard let familyID else { return }

        let familyIDString = familyID.uuidString
        startPresenceSyncIfNeeded(familyID: familyID)
        guard activeRealtimeFamilyID != familyIDString else { return }

        activeRealtimeFamilyID = familyIDString
        Task {
            await FirebaseSyncService.shared.stopAllFamilyListeners()
            await FirebaseSyncService.shared.startListeningToFamily(familyID: familyIDString) { [weak self] remoteState in
                self?.applyRealtimeFamilyCloudState(remoteState)
            }
            await MainActor.run {
                self.syncStatus = .live(.now)
            }
        }
    }

    private func startPresenceSyncIfNeeded(familyID: UUID) {
        guard let member = currentMembership else {
            onlineMemberIDs = []
            presenceHeartbeatTask?.cancel()
            presenceHeartbeatTask = nil
            activePresenceKey = nil
            return
        }

        let familyIDString = familyID.uuidString
        let presenceKey = "\(familyIDString)::\(member.id.uuidString)"
        guard activePresenceKey != presenceKey else { return }

        activePresenceKey = presenceKey
        presenceHeartbeatTask?.cancel()

        presenceHeartbeatTask = Task { [weak self] in
            await FirebaseSyncService.shared.stopAllPresenceListeners()
            await FirebaseSyncService.shared.startListeningToPresence(
                familyID: familyIDString,
                activeWithin: 5 * 60
            ) { [weak self] activeIDs in
                self?.onlineMemberIDs = activeIDs
            }

            while !Task.isCancelled {
                guard self != nil else { return }
                await FirebaseSyncService.shared.markMemberActive(
                    familyID: familyIDString,
                    memberID: member.id.uuidString,
                    displayName: member.displayName
                )

                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private func applyRealtimeFamilyCloudState(_ remote: FamilyCloudState) {
        let previousCurrentFamilyID = currentUser?.currentFamilyID

        applyFamilyCloudState(remote)
        ensureDemoAccounts()
        store.save(snapshot)
        syncStatus = .live(.now)

        if currentUser?.currentFamilyID != previousCurrentFamilyID {
            Task { await syncCurrentUserFamilySelectionToCloud() }
        }

        startRealtimeSyncIfNeeded()
    }

    private func bootstrapCloudSyncIfNeeded() async {
        let authUID = currentFirebaseAuthUID()
        let familyID = currentFamily?.id.uuidString
        let syncKey = "\(authUID ?? "none")::\(familyID ?? "none")"

        guard syncKey != lastBootstrappedSyncKey else { return }
        guard !hasBootstrappedCloudSync else { return }
        hasBootstrappedCloudSync = true
        defer { hasBootstrappedCloudSync = false }

        guard let localFamilyState = makeCurrentFamilyCloudState() else {
            lastBootstrappedSyncKey = syncKey
            return
        }

        syncStatus = .syncing
        if let remoteFamilyState = await FirebaseSyncService.shared.bootstrapFamily(
            localState: localFamilyState.state,
            familyID: localFamilyState.familyID
        ) {
            applyFamilyCloudState(remoteFamilyState)
            ensureDemoAccounts()
            store.save(snapshot)
        }
        lastBootstrappedSyncKey = syncKey
        syncStatus = .live(.now)
        startRealtimeSyncIfNeeded()
    }

    private func recoverMissingFamilyIfNeeded() async {
        guard currentUser != nil, currentFamily == nil, let firebaseUID = currentFirebaseAuthUID() else {
            return
        }

        syncStatus = .syncing
        let didRecover = await loadAndApplyRemoteCurrentFamilyID(firebaseUID: firebaseUID)
        syncStatus = didRecover ? .live(.now) : .idle
        startRealtimeSyncIfNeeded()
    }

    private func makeCurrentFamilyCloudState() -> (familyID: String, state: FamilyCloudState)? {
        guard let family = currentFamily else { return nil }
        guard let state = makeFamilyCloudState(for: family.id) else { return nil }
        return (family.id.uuidString, state)
    }

    private func makeFamilyCloudState(for familyID: UUID) -> FamilyCloudState? {
        guard let family = snapshot.families.first(where: { $0.id == familyID }) else { return nil }

        let memberships = snapshot.memberships.filter { $0.familyID == familyID }
        let joinRequests = snapshot.joinRequests.filter { $0.familyID == familyID }
        let userIDs = Set(memberships.map(\.userID) + joinRequests.map(\.userID) + [family.createdBy])
        let users = snapshot.users.filter { userIDs.contains($0.id) }

        return FamilyCloudState(
            family: family,
            users: users,
            memberships: memberships,
            joinRequests: joinRequests,
            tasks: snapshot.tasks.filter { $0.familyID == familyID },
            scheduleEntries: snapshot.scheduleEntries.filter { $0.familyID == familyID },
            groupMessages: snapshot.groupMessages.filter { $0.familyID == familyID },
            savedChatMessages: snapshot.savedChatMessages.filter { $0.familyID == familyID },
            expenseTransactions: snapshot.expenseTransactions.filter { $0.familyID == familyID },
            savingsGoals: snapshot.savingsGoals.filter { $0.familyID == familyID }
        )
    }

    private func applyFamilyCloudState(_ remote: FamilyCloudState) {
        let familyID = remote.family.id
        let currentAuthUID = currentFirebaseAuthUID()
        let currentEmail = currentUser?.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        if let remoteCurrentUser = remote.users.first(where: { user in
            if let currentAuthUID, user.firebaseUID == currentAuthUID {
                return true
            }
            return !currentEmail.isEmpty && user.email.lowercased() == currentEmail
        }) {
            snapshot.currentUserID = remoteCurrentUser.id
        }

        if let familyIndex = snapshot.families.firstIndex(where: { $0.id == familyID }) {
            snapshot.families[familyIndex] = remote.family
        } else {
            snapshot.families.append(remote.family)
        }

        snapshot.memberships.removeAll { $0.familyID == familyID }
        snapshot.memberships.append(contentsOf: remote.memberships)

        snapshot.joinRequests.removeAll { $0.familyID == familyID }
        snapshot.joinRequests.append(contentsOf: remote.joinRequests)

        snapshot.tasks.removeAll { $0.familyID == familyID }
        snapshot.tasks.append(contentsOf: remote.tasks)

        snapshot.scheduleEntries.removeAll { $0.familyID == familyID }
        snapshot.scheduleEntries.append(contentsOf: remote.scheduleEntries)

        snapshot.groupMessages.removeAll { $0.familyID == familyID }
        snapshot.groupMessages.append(contentsOf: remote.groupMessages)

        snapshot.savedChatMessages.removeAll { $0.familyID == familyID }
        snapshot.savedChatMessages.append(contentsOf: remote.savedChatMessages)

        snapshot.expenseTransactions.removeAll { $0.familyID == familyID }
        snapshot.expenseTransactions.append(contentsOf: remote.expenseTransactions)

        snapshot.savingsGoals.removeAll { $0.familyID == familyID }
        snapshot.savingsGoals.append(contentsOf: remote.savingsGoals)

        let remoteUsersByID = Dictionary(uniqueKeysWithValues: remote.users.map { ($0.id, $0) })
        for (id, user) in remoteUsersByID {
            if let userIndex = snapshot.users.firstIndex(where: { $0.id == id }) {
                var merged = user
                if snapshot.currentUserID == id {
                    if let currentAuthUID {
                        merged.firebaseUID = currentAuthUID
                    }
                    if !currentEmail.isEmpty {
                        merged.email = currentEmail
                    } else if !snapshot.users[userIndex].email.isEmpty {
                        merged.email = snapshot.users[userIndex].email
                    }
                }
                snapshot.users[userIndex] = merged
            } else {
                var merged = user
                if snapshot.currentUserID == id {
                    if let currentAuthUID {
                        merged.firebaseUID = currentAuthUID
                    }
                    if !currentEmail.isEmpty {
                        merged.email = currentEmail
                    }
                }
                snapshot.users.append(merged)
            }
        }

        if let currentUserID = snapshot.currentUserID,
           let currentUserIndex = snapshot.users.firstIndex(where: { $0.id == currentUserID }) {
            let isCurrentUserMember = snapshot.memberships.contains {
                $0.familyID == familyID && $0.userID == currentUserID
            }

            if isCurrentUserMember {
                snapshot.users[currentUserIndex].currentFamilyID = familyID
            } else if snapshot.users[currentUserIndex].currentFamilyID == familyID {
                snapshot.users[currentUserIndex].currentFamilyID = nil
            }
        }
    }

    private func syncOrCreateLocalUser(firebaseUID: String, email: String, username: String) {
        if let index = snapshot.users.firstIndex(where: { $0.firebaseUID == firebaseUID }) {
            snapshot.users[index].email = email
            snapshot.users[index].username = username
            snapshot.users[index].password = ""
            snapshot.currentUserID = snapshot.users[index].id
            return
        }

        if let index = snapshot.users.firstIndex(where: { $0.email.lowercased() == email.lowercased() }) {
            snapshot.users[index].firebaseUID = firebaseUID
            snapshot.users[index].username = username
            snapshot.users[index].password = ""
            snapshot.currentUserID = snapshot.users[index].id
            return
        }

        let user = UserAccount(
            id: UUID(),
            username: username,
            email: email,
            password: "",
            firebaseUID: firebaseUID,
            currentFamilyID: nil
        )
        snapshot.users.append(user)
        snapshot.currentUserID = user.id
    }

    private func syncLocalSessionFromFirebaseAuth() async {
        guard let uid = currentFirebaseAuthUID() else {
            snapshot.currentUserID = nil
            store.save(snapshot)
            return
        }

#if canImport(FirebaseAuth)
        let email = Auth.auth().currentUser?.email?.lowercased() ?? ""
        let fallbackUsername = email.split(separator: "@").first.map(String.init) ?? "User"
        syncOrCreateLocalUser(firebaseUID: uid, email: email, username: fallbackUsername)
        _ = await loadAndApplyRemoteCurrentFamilyID(firebaseUID: uid)
        store.save(snapshot)
#endif
    }

    @discardableResult
    private func loadAndApplyRemoteCurrentFamilyID(firebaseUID: String) async -> Bool {
        let currentEmail = currentUser?.email

        if let remoteCurrentFamilyID = await FirebaseSyncService.shared.loadCurrentFamilyID(for: firebaseUID),
           let familyUUID = UUID(uuidString: remoteCurrentFamilyID) {
            if let remoteFamilyState = await FirebaseSyncService.shared.loadFamilyState(familyID: remoteCurrentFamilyID) {
                applyFamilyCloudState(remoteFamilyState)
                return true
            }

            if let currentUserID = snapshot.currentUserID,
               let index = snapshot.users.firstIndex(where: { $0.id == currentUserID }) {
                snapshot.users[index].currentFamilyID = familyUUID
            }
            return false
        }

        guard let remoteFamilyState = await FirebaseSyncService.shared.loadFamilyStateForMember(
            firebaseUID: firebaseUID,
            email: currentEmail
        ) else {
            return false
        }

        applyFamilyCloudState(remoteFamilyState)

        if currentFamily?.id == remoteFamilyState.family.id {
            await FirebaseSyncService.shared.saveCurrentFamilyID(
                remoteFamilyState.family.id.uuidString,
                for: firebaseUID
            )
        }
        return currentFamily?.id == remoteFamilyState.family.id
    }

    private func syncCurrentUserFamilySelectionToCloud() async {
        guard let firebaseUID = currentFirebaseAuthUID() else { return }
        let familyID = currentUser?.currentFamilyID?.uuidString
        await FirebaseSyncService.shared.saveCurrentFamilyID(familyID, for: firebaseUID)
    }

    private func currentFirebaseAuthUID() -> String? {
#if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
#else
        return nil
#endif
    }

    private func mapFirebaseAuthError(_ error: Error) -> String {
#if canImport(FirebaseAuth)
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail:
            return "Invalid email format."
        case .wrongPassword, .invalidCredential:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "Email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .userNotFound:
            return "Account not found."
        case .networkError:
            return "Network error. Please try again."
        default:
            return error.localizedDescription
        }
#else
        return error.localizedDescription
#endif
    }
}
