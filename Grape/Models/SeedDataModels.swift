import Foundation

nonisolated enum FamilyRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case owner = "Owner"
    case admin = "Admin"
    case parent = "Parent"
    case child = "Child"

    var id: String { rawValue }

    var canManageMembers: Bool {
        self == .owner || self == .admin
    }
}

nonisolated struct UserAccount: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var username: String
    var email: String
    var password: String
    var firebaseUID: String? = nil
    var currentFamilyID: UUID?
}

nonisolated struct FamilyGroup: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var inviteCode: String
    var createdBy: UUID
    var createdAt: Date
}

nonisolated struct FamilyMembership: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var userID: UUID
    var displayName: String
    var role: FamilyRole
    var avatarAssetName: String
    var joinedAt: Date
}

nonisolated struct FamilyJoinRequest: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var userID: UUID
    var displayName: String
    var requestedRole: FamilyRole
    var avatarAssetName: String
    var requestedAt: Date
}

nonisolated struct TaskRecord: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var title: String
    var assigneeMemberID: UUID?
    var dueDate: Date
    var isCompleted: Bool
    var createdByUserID: UUID
}

nonisolated struct ScheduleEntry: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var date: Date
    var title: String
    var subtitle: String?
}

nonisolated struct GroupMessage: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var senderMemberID: UUID
    var senderName: String
    var text: String
    var sentAt: Date
}

nonisolated struct SavedChatMessage: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var messageID: UUID
    var savedByMemberID: UUID
    var senderName: String
    var text: String
    var messageSentAt: Date
    var savedAt: Date
}

nonisolated enum FinancialTransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case income = "Income"
    case expense = "Expense"

    var id: String { rawValue }
}

nonisolated enum FinancialCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case groceries = "Groceries"
    case dining = "Dining"
    case transport = "Transport"
    case home = "Home"
    case education = "Education"
    case health = "Health"
    case income = "Income"
    case savings = "Savings"
    case other = "Other"

    var id: String { rawValue }
}

nonisolated struct ExpenseTransaction: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var title: String
    var date: Date
    var amount: Double
    var kind: FinancialTransactionKind
    var category: FinancialCategory

    var signedAmount: Double {
        switch kind {
        case .income:
            return abs(amount)
        case .expense:
            return -abs(amount)
        }
    }

    init(
        id: UUID,
        familyID: UUID,
        title: String,
        date: Date,
        amount: Double,
        kind: FinancialTransactionKind = .expense,
        category: FinancialCategory = .other
    ) {
        self.id = id
        self.familyID = familyID
        self.title = title
        self.date = date
        self.amount = abs(amount)
        self.kind = kind
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyID
        case title
        case date
        case amount
        case kind
        case category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        familyID = try container.decode(UUID.self, forKey: .familyID)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)

        let storedAmount = try container.decode(Double.self, forKey: .amount)
        kind = try container.decodeIfPresent(FinancialTransactionKind.self, forKey: .kind)
            ?? (storedAmount > 0 ? .income : .expense)
        category = try container.decodeIfPresent(FinancialCategory.self, forKey: .category)
            ?? (kind == .income ? .income : .other)
        amount = abs(storedAmount)
    }
}

nonisolated struct SavingsGoal: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var familyID: UUID
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date?
    var updatedAt: Date
}

nonisolated struct AppDataSnapshot: Codable, Sendable {
    var currentUserID: UUID?
    var users: [UserAccount]
    var families: [FamilyGroup]
    var memberships: [FamilyMembership]
    var joinRequests: [FamilyJoinRequest]
    var tasks: [TaskRecord]
    var scheduleEntries: [ScheduleEntry]
    var groupMessages: [GroupMessage]
    var savedChatMessages: [SavedChatMessage]
    var expenseTransactions: [ExpenseTransaction]
    var savingsGoals: [SavingsGoal]

    enum CodingKeys: String, CodingKey {
        case currentUserID
        case users
        case families
        case memberships
        case joinRequests
        case tasks
        case scheduleEntries
        case groupMessages
        case savedChatMessages
        case expenseTransactions
        case savingsGoals
    }

    init(
        currentUserID: UUID?,
        users: [UserAccount],
        families: [FamilyGroup],
        memberships: [FamilyMembership],
        joinRequests: [FamilyJoinRequest],
        tasks: [TaskRecord],
        scheduleEntries: [ScheduleEntry],
        groupMessages: [GroupMessage],
        savedChatMessages: [SavedChatMessage] = [],
        expenseTransactions: [ExpenseTransaction],
        savingsGoals: [SavingsGoal] = []
    ) {
        self.currentUserID = currentUserID
        self.users = users
        self.families = families
        self.memberships = memberships
        self.joinRequests = joinRequests
        self.tasks = tasks
        self.scheduleEntries = scheduleEntries
        self.groupMessages = groupMessages
        self.savedChatMessages = savedChatMessages
        self.expenseTransactions = expenseTransactions
        self.savingsGoals = savingsGoals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentUserID = try container.decodeIfPresent(UUID.self, forKey: .currentUserID)
        users = try container.decodeIfPresent([UserAccount].self, forKey: .users) ?? []
        families = try container.decodeIfPresent([FamilyGroup].self, forKey: .families) ?? []
        memberships = try container.decodeIfPresent([FamilyMembership].self, forKey: .memberships) ?? []
        joinRequests = try container.decodeIfPresent([FamilyJoinRequest].self, forKey: .joinRequests) ?? []
        tasks = try container.decodeIfPresent([TaskRecord].self, forKey: .tasks) ?? []
        scheduleEntries = try container.decodeIfPresent([ScheduleEntry].self, forKey: .scheduleEntries) ?? []
        groupMessages = try container.decodeIfPresent([GroupMessage].self, forKey: .groupMessages) ?? []
        savedChatMessages = try container.decodeIfPresent([SavedChatMessage].self, forKey: .savedChatMessages) ?? []
        expenseTransactions = try container.decodeIfPresent([ExpenseTransaction].self, forKey: .expenseTransactions) ?? []
        savingsGoals = try container.decodeIfPresent([SavingsGoal].self, forKey: .savingsGoals) ?? []
    }
}

nonisolated struct FamilyCloudState: Codable, Sendable {
    var family: FamilyGroup
    var users: [UserAccount]
    var memberships: [FamilyMembership]
    var joinRequests: [FamilyJoinRequest]
    var tasks: [TaskRecord]
    var scheduleEntries: [ScheduleEntry]
    var groupMessages: [GroupMessage]
    var savedChatMessages: [SavedChatMessage]
    var expenseTransactions: [ExpenseTransaction]
    var savingsGoals: [SavingsGoal]
}

enum SeedData {
    static let demoUser1 = UserAccount(
        id: UUID(uuidString: "A3D9F101-12D0-45FC-9A6A-E57E84CE7761")!,
        username: "tester001",
        email: "tester001@app.com",
        password: "123456",
        currentFamilyID: nil
    )

    static let demoUser2 = UserAccount(
        id: UUID(uuidString: "B4447F98-7198-44D8-A9A0-261B6BE8ED6A")!,
        username: "tester002",
        email: "tester002@app.com",
        password: "123456",
        firebaseUID: nil,
        currentFamilyID: nil
    )

    static let demoUser3 = UserAccount(
        id: UUID(uuidString: "C5E170B5-8E86-4EAB-B57A-3D1E8EA8B851")!,
        username: "tester003",
        email: "tester003@app.com",
        password: "123456",
        currentFamilyID: nil
    )

    static let demoAccounts: [UserAccount] = [demoUser1, demoUser2, demoUser3]

    static let avatarOptions = ["father", "mother", "son", "daughter"]

    static func makeInitialSnapshot(now: Date = .now) -> AppDataSnapshot {
        AppDataSnapshot(
            currentUserID: nil,
            users: demoAccounts,
            families: [],
            memberships: [],
            joinRequests: [],
            tasks: [],
            scheduleEntries: [],
            groupMessages: [],
            savedChatMessages: [],
            expenseTransactions: []
        )
    }
}
