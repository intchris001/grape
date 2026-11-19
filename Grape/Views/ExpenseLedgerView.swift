import SwiftUI

struct ExpenseLedgerView: View {
    @EnvironmentObject private var appState: AppState

    @State private var draftTitle = ""
    @State private var draftAmountText = ""
    @State private var draftKind: FinancialTransactionKind = .expense
    @State private var draftCategory: FinancialCategory = .groceries
    @State private var draftPrediction: FinanceInputPrediction?
    @State private var didManuallyPickKind = false
    @State private var didManuallyPickCategory = false
    @State private var isApplyingAutoKind = false
    @State private var isApplyingAutoCategory = false
    @State private var editingTransaction: ExpenseTransaction?
    @FocusState private var isAmountFocused: Bool

    @State private var goalTitle = "Emergency Fund"
    @State private var goalTargetText = ""
    @State private var goalCurrentText = ""
    @State private var goalTargetDate = Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
    @State private var isEditingGoal = false

    private var transactions: [ExpenseTransaction] {
        appState.expenseTransactions
    }

    private var monthTransactions: [ExpenseTransaction] {
        transactions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    private var monthlyIncome: Double {
        monthTransactions.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
    }

    private var monthlyExpense: Double {
        monthTransactions.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var monthlyNet: Double {
        monthlyIncome - monthlyExpense
    }

    private var savingsRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        return monthlyNet / monthlyIncome
    }

    private var goal: SavingsGoal? {
        appState.currentSavingsGoal
    }

    private var lastMonthTransactions: [ExpenseTransaction] {
        guard let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: .now) else { return [] }
        return transactions.filter { Calendar.current.isDate($0.date, equalTo: lastMonth, toGranularity: .month) }
    }

    private var categorySpend: [(category: FinancialCategory, amount: Double, delta: Double)] {
        let previous = Dictionary(grouping: lastMonthTransactions.filter { $0.kind == .expense }, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        return Dictionary(grouping: monthTransactions.filter { $0.kind == .expense }, by: \.category)
            .map { category, items in
                let amount = items.reduce(0) { $0 + $1.amount }
                return (category: category, amount: amount, delta: amount - (previous[category] ?? 0))
            }
            .sorted { $0.amount > $1.amount }
    }

    private var bodyInsight: String {
        if monthlyIncome <= 0 {
            return "Add this month's income to track available savings."
        }
        if monthlyNet < 0 {
            return "Spending is above income this month."
        }
        if savingsRate >= 0.2 {
            return "This month is on track."
        }
        return "Cash flow is positive this month."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                heroHeader
                savingsProgressSection
                cashFlowStrip
                trendSection
                categorySection
                inputSection
                recentSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 116)
        }
        .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: hydrateGoalDraft)
        .onChange(of: appState.currentSavingsGoal) { _, _ in hydrateGoalDraft() }
        .onChange(of: draftKind) { _, newKind in
            guard !isApplyingAutoKind else { return }
            didManuallyPickKind = true
            didManuallyPickCategory = false
            updateInputPrediction(for: draftTitle, kind: newKind)
        }
        .onChange(of: draftTitle) { _, newTitle in
            updateInputPrediction(for: newTitle, kind: draftKind)
        }
        .onChange(of: draftAmountText) { _, _ in
            updateInputPrediction(for: draftTitle, kind: draftKind)
        }
        .onChange(of: draftCategory) { _, _ in
            guard !isApplyingAutoCategory else { return }
            didManuallyPickCategory = true
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditorSheet(
                transaction: transaction,
                currency: currency,
                onSave: { title, amount, kind, category, date in
                    _ = appState.updateFinanceTransaction(
                        id: transaction.id,
                        title: title,
                        amount: amount,
                        kind: kind,
                        category: category,
                        date: date
                    )
                    editingTransaction = nil
                },
                onDelete: {
                    appState.deleteFinanceTransaction(id: transaction.id)
                    editingTransaction = nil
                }
            )
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                AssetCircleIcon(assetName: "Expense", iconSize: 34, circleSize: 66, iconScale: 1.18)
                    .shadow(color: AppStyle.Palette.primary.opacity(0.16), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Wallet")
                        .font(AppStyle.Typography.section)
                        .foregroundStyle(AppStyle.Palette.textPrimary)

                    Text("Monthly cash flow overview")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }

                Spacer()

                Text(percent(savingsRate))
                    .font(AppStyle.Typography.label.monospacedDigit())
                    .foregroundStyle(AppStyle.Palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppStyle.Palette.primarySoft.opacity(0.88), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(currency(monthlyNet))
                    .font(AppStyle.Typography.titleL)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("net cash flow this month")
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)
            }

            Text(bodyInsight)
                .font(AppStyle.Typography.label)
                .foregroundStyle(AppStyle.Palette.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppStyle.Palette.primarySoft.opacity(0.58),
                            AppStyle.Palette.surface.opacity(0.80),
                            AppStyle.Palette.accent.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .glassPanel(cornerRadius: 28, strokeOpacity: 0.96)
    }

    private var savingsProgressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Savings Goal")

            if let goal {
                SavingsGoalProgressView(
                    goal: goal,
                    monthlyNet: monthlyNet,
                    currency: currency,
                    percent: percent
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Set a savings goal to track monthly progress.")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                    GoalEditor(
                        goalTitle: $goalTitle,
                        goalTargetText: $goalTargetText,
                        goalCurrentText: $goalCurrentText,
                        goalTargetDate: $goalTargetDate,
                        actionTitle: "Create Goal",
                        onSave: saveGoal
                    )
                }
            }

            if goal != nil {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isEditingGoal.toggle()
                    }
                } label: {
                    Label(isEditingGoal ? "Hide goal settings" : "Adjust goal", systemImage: "slider.horizontal.3")
                        .font(AppStyle.Typography.label)
                        .foregroundStyle(AppStyle.Palette.primary)
                }
                .buttonStyle(.plain)

            }

            if goal != nil && isEditingGoal {
                GoalEditor(
                    goalTitle: $goalTitle,
                    goalTargetText: $goalTargetText,
                    goalCurrentText: $goalCurrentText,
                    goalTargetDate: $goalTargetDate,
                    actionTitle: "Update Goal",
                    onSave: saveGoal
                )
            }
        }
    }

    private var cashFlowStrip: some View {
        HStack(spacing: 12) {
            FinanceStatTile(title: "Income", value: currency(monthlyIncome), color: FinancePalette.income)
            FinanceStatTile(title: "Spending", value: currency(monthlyExpense), color: FinancePalette.expense)
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Cash Flow Trend")
            ComboCashFlowChart(months: monthlyBuckets, currency: currency)
                .frame(height: 168)
                .padding(16)
                .glassPanel(cornerRadius: 24, strokeOpacity: 0.9)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Spending Mix")

            if categorySpend.isEmpty {
                EmptyStateView(
                    iconName: "chart.pie",
                    title: "No Spending",
                    message: "No spending recorded this month."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(categorySpend, id: \.category) { item in
                        CategorySpendRow(
                            category: item.category,
                            amount: item.amount,
                            delta: item.delta,
                            maxAmount: categorySpend.first?.amount ?? item.amount,
                            color: FinancePalette.color(for: item.category),
                            currency: currency
                        )
                    }
                }
                .padding(16)
                .glassPanel(cornerRadius: 24, strokeOpacity: 0.9)
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Record Transaction")

            VStack(spacing: 12) {
                Picker("Type", selection: $draftKind) {
                    ForEach(FinancialTransactionKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Title", text: $draftTitle)
                    .glassInputField()

                TextField("Amount in AUD", text: $draftAmountText)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .glassInputField()
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isAmountFocused = false
                            }
                            .font(AppStyle.Typography.label)
                            .foregroundStyle(AppStyle.Palette.primary)
                        }
                    }

                if let draftPrediction {
                    FinancePredictionRow(
                        prediction: draftPrediction,
                        currency: currency,
                        canApplyAmount: draftAmountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        onApplyAmount: {
                            if let amount = draftPrediction.suggestedAmount {
                                draftAmountText = plainNumber(amount)
                            }
                        }
                    )
                }

                FinanceCategoryPicker(
                    selection: $draftCategory,
                    categories: availableCategories
                )

                Button("Save Transaction") {
                    saveTransaction()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppStyle.Palette.primary)
                .font(AppStyle.Typography.label)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(draftAmountText) == nil)
            }
            .padding(16)
            .glassPanel(cornerRadius: 24, strokeOpacity: 0.9)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Recent Activity")

            if transactions.isEmpty {
                EmptyStateView(
                    iconName: "creditcard.trianglebadge.exclamationmark",
                    title: "No Transactions",
                    message: "You haven't recorded any expenses or income yet. Start tracking to see your cash flow."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(transactions.prefix(8).enumerated()), id: \.element.id) { index, item in
                        TransactionRow(item: item, currency: currency)
                            .padding(.vertical, 12)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    AppStyle.Haptic.play(.medium)
                                    appState.deleteFinanceTransaction(id: item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    AppStyle.Haptic.play(.light)
                                    editingTransaction = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(AppStyle.Palette.primary)
                            }
                            .contextMenu {
                                Button {
                                    editingTransaction = item
                                } label: {
                                    Label("Edit Transaction", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    appState.deleteFinanceTransaction(id: item.id)
                                } label: {
                                    Label("Delete Transaction", systemImage: "trash")
                                }
                            }

                        if index != min(transactions.count, 8) - 1 {
                            Divider().overlay(AppStyle.Palette.separator)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .glassPanel(cornerRadius: 24, strokeOpacity: 0.9)
            }
        }
    }

    private var availableCategories: [FinancialCategory] {
        draftKind == .income ? [.income] : FinancialCategory.allCases.filter { $0 != .income }
    }

    private var monthlyBuckets: [CashFlowMonth] {
        let calendar = Calendar.current
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now

        return (0..<6).reversed().compactMap { offset in
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: startOfCurrentMonth) else {
                return nil
            }
            let items = transactions.filter { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
            let income = items.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
            let expense = items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
            return CashFlowMonth(
                label: monthStart.formatted(.dateTime.month(.abbreviated)),
                income: income,
                expense: expense
            )
        }
    }

    private func saveTransaction() {
        guard let draft = FinanceTransactionDraftParser.transactionDraft(title: draftTitle, amountText: draftAmountText) else { return }
        appState.addFinanceTransaction(
            title: draft.title,
            amount: draft.amount,
            kind: draftKind,
            category: draftCategory
        )
        draftTitle = ""
        draftAmountText = ""
        draftPrediction = nil
        didManuallyPickKind = false
        didManuallyPickCategory = false
        draftCategory = draftKind == .income ? .income : .groceries
    }

    private func updateInputPrediction(for title: String, kind: FinancialTransactionKind) {
        let prediction = FinanceInputPredictor.prediction(
            for: title,
            amountText: draftAmountText,
            selectedKind: kind,
            history: transactions
        )

        guard let prediction, prediction.confidence >= 0.72 else {
            draftPrediction = nil
            return
        }
        draftPrediction = prediction

        if !didManuallyPickKind {
            setDraftKind(prediction.kind)
        }
        guard !didManuallyPickCategory else { return }
        setDraftCategory(prediction.category)
    }

    private func setDraftKind(_ kind: FinancialTransactionKind) {
        guard draftKind != kind else { return }
        isApplyingAutoKind = true
        draftKind = kind
        DispatchQueue.main.async {
            isApplyingAutoKind = false
        }
    }

    private func setDraftCategory(_ category: FinancialCategory) {
        guard draftCategory != category else { return }
        isApplyingAutoCategory = true
        draftCategory = category
        DispatchQueue.main.async {
            isApplyingAutoCategory = false
        }
    }

    private func saveGoal() {
        guard let targetAmount = Double(goalTargetText), targetAmount > 0 else { return }
        guard !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let currentAmount = Double(goalCurrentText) ?? 0
        appState.setSavingsGoal(
            title: goalTitle,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: goalTargetDate
        )
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditingGoal = false
        }
    }

    private func hydrateGoalDraft() {
        guard let goal else { return }
        goalTitle = goal.title
        goalTargetText = plainNumber(goal.targetAmount)
        goalCurrentText = plainNumber(goal.currentAmount)
        goalTargetDate = goal.targetDate ?? goalTargetDate
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.locale = Locale(identifier: "en_AU")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "A$\(value)"
    }

    private func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    private func plainNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}


struct FinanceCategorySuggestion: Equatable {
    let category: FinancialCategory
    let confidence: Double
    let reason: String

    var confidenceLabel: String {
        if confidence >= 0.82 { return "High confidence" }
        if confidence >= 0.62 { return "Medium confidence" }
        return "Low confidence"
    }
}

struct FinanceInputPrediction: Equatable {
    let kind: FinancialTransactionKind
    let category: FinancialCategory
    let suggestedAmount: Double?
    let confidence: Double
    let reason: String

    var confidenceLabel: String {
        if confidence >= 0.82 { return "High confidence" }
        if confidence >= 0.62 { return "Medium confidence" }
        return "Low confidence"
    }
}

enum FinanceTransactionDraftParser {
    static func transactionDraft(title: String, amountText: String) -> (title: String, amount: Double)? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let amount = parseAmount(amountText), amount > 0 {
            return (trimmedTitle, amount)
        }

        guard let extracted = trailingAmount(in: trimmedTitle), extracted.amount > 0 else {
            return nil
        }
        let cleanTitle = extracted.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        return (cleanTitle, extracted.amount)
    }

    static func amount(in text: String) -> Double? {
        guard let range = text.range(
            of: #"(?:A\$|\$)\s*\d+(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:,\d{3})*\.\d{1,2}"#,
            options: .regularExpression
        ) else {
            return nil
        }
        return parseAmount(String(text[range]))
    }

    private static func trailingAmount(in title: String) -> (title: String, amount: Double)? {
        guard let range = title.range(
            of: #"(?:A\$|\$)?\s*\d+(?:,\d{3})*(?:\.\d{1,2})?\s*$"#,
            options: .regularExpression
        ) else {
            return nil
        }
        guard let amount = parseAmount(String(title[range])) else { return nil }
        let titleWithoutAmount = String(title[..<range.lowerBound])
        return (titleWithoutAmount, amount)
    }

    private static func parseAmount(_ rawValue: String) -> Double? {
        let cleaned = rawValue
            .replacingOccurrences(of: "A$", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }
}

enum FinanceInputPredictor {
    private struct KindRule {
        let text: String
        let kind: FinancialTransactionKind
        let score: Double
        let label: String
    }

    private struct MerchantProfile {
        let aliases: [String]
        let kind: FinancialTransactionKind
        let category: FinancialCategory
        let confidence: Double
        let label: String
    }

    private static let kindRules: [KindRule] = [
        KindRule(text: "salary", kind: .income, score: 0.96, label: "salary"),
        KindRule(text: "payroll", kind: .income, score: 0.96, label: "payroll"),
        KindRule(text: "wage", kind: .income, score: 0.92, label: "wage"),
        KindRule(text: "bonus", kind: .income, score: 0.88, label: "bonus"),
        KindRule(text: "dividend", kind: .income, score: 0.84, label: "dividend"),
        KindRule(text: "interest", kind: .income, score: 0.78, label: "interest"),
        KindRule(text: "refund", kind: .income, score: 0.74, label: "refund"),
        KindRule(text: "reimbursement", kind: .income, score: 0.86, label: "reimbursement"),
        KindRule(text: "rent", kind: .expense, score: 0.88, label: "rent"),
        KindRule(text: "coles", kind: .expense, score: 0.86, label: "merchant"),
        KindRule(text: "woolworths", kind: .expense, score: 0.86, label: "merchant"),
        KindRule(text: "uber", kind: .expense, score: 0.76, label: "merchant"),
        KindRule(text: "coffee", kind: .expense, score: 0.72, label: "coffee")
    ]

    private static let merchantProfiles: [MerchantProfile] = [
        MerchantProfile(aliases: ["coles", "coles supermarket"], kind: .expense, category: .groceries, confidence: 0.92, label: "Coles"),
        MerchantProfile(aliases: ["woolworths", "woolies"], kind: .expense, category: .groceries, confidence: 0.92, label: "Woolworths"),
        MerchantProfile(aliases: ["aldi"], kind: .expense, category: .groceries, confidence: 0.9, label: "ALDI"),
        MerchantProfile(aliases: ["iga"], kind: .expense, category: .groceries, confidence: 0.86, label: "IGA"),
        MerchantProfile(aliases: ["costco"], kind: .expense, category: .groceries, confidence: 0.86, label: "Costco"),
        MerchantProfile(aliases: ["uber eats", "doordash", "menulog"], kind: .expense, category: .dining, confidence: 0.94, label: "food delivery"),
        MerchantProfile(aliases: ["mcdonald", "kfc", "hungry jacks", "dominos", "subway"], kind: .expense, category: .dining, confidence: 0.88, label: "restaurant"),
        MerchantProfile(aliases: ["starbucks", "gloria jeans", "coffee club"], kind: .expense, category: .dining, confidence: 0.84, label: "cafe"),
        MerchantProfile(aliases: ["opal", "transport nsw"], kind: .expense, category: .transport, confidence: 0.92, label: "public transport"),
        MerchantProfile(aliases: ["bp", "shell", "ampol", "caltex", "7 eleven fuel"], kind: .expense, category: .transport, confidence: 0.86, label: "fuel"),
        MerchantProfile(aliases: ["uber", "didi", "taxi"], kind: .expense, category: .transport, confidence: 0.78, label: "ride share"),
        MerchantProfile(aliases: ["chemist warehouse", "priceline pharmacy", "pharmacy"], kind: .expense, category: .health, confidence: 0.94, label: "pharmacy"),
        MerchantProfile(aliases: ["medicare", "doctor", "clinic", "dental"], kind: .expense, category: .health, confidence: 0.84, label: "health care"),
        MerchantProfile(aliases: ["bunnings", "ikea", "kmart", "target", "big w"], kind: .expense, category: .home, confidence: 0.78, label: "home retail"),
        MerchantProfile(aliases: ["netflix", "spotify", "apple", "google", "amazon prime"], kind: .expense, category: .other, confidence: 0.74, label: "subscription"),
        MerchantProfile(aliases: ["salary", "payroll", "wage"], kind: .income, category: .income, confidence: 0.94, label: "pay income"),
        MerchantProfile(aliases: ["bonus", "dividend", "interest", "refund", "reimbursement"], kind: .income, category: .income, confidence: 0.82, label: "income keyword")
    ]

    static func prediction(
        for title: String,
        amountText: String,
        selectedKind: FinancialTransactionKind,
        history: [ExpenseTransaction]
    ) -> FinanceInputPrediction? {
        let parsedDraft = FinanceTransactionDraftParser.transactionDraft(title: title, amountText: amountText)
        let cleanTitle = parsedDraft?.title ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = FinanceCategoryClassifier.normalizedText(cleanTitle)
        guard !normalized.isEmpty else { return nil }

        let learned = learnedPrediction(for: normalized, history: history)
        let merchant = merchantPrediction(for: normalized)
        let ruleKind = predictedKind(from: normalized)
        let kind = learned?.kind ?? merchant?.kind ?? ruleKind?.kind ?? selectedKind
        let amount = parsedDraft?.amount ?? learned?.suggestedAmount
        let categorySuggestion = FinanceCategoryClassifier.suggestion(
            for: cleanTitle,
            kind: kind,
            amount: amount,
            history: history
        )
        let category = learned?.category ?? merchant?.category ?? categorySuggestion.category

        let confidence = [
            learned?.confidence,
            merchant?.confidence,
            ruleKind?.score,
            categorySuggestion.confidence
        ]
            .compactMap { $0 }
            .max() ?? 0.5

        let reason: String
        if let learned {
            reason = learned.reason
        } else if let merchant {
            reason = "Matched \(merchant.label)"
        } else if let ruleKind {
            reason = "Matched \(ruleKind.label)"
        } else {
            reason = categorySuggestion.reason
        }

        return FinanceInputPrediction(
            kind: kind,
            category: category,
            suggestedAmount: amount,
            confidence: min(confidence, 0.96),
            reason: reason
        )
    }

    private static func merchantPrediction(for normalized: String) -> MerchantProfile? {
        merchantProfiles
            .filter { profile in
                profile.aliases.contains { normalized.contains($0) }
            }
            .max { $0.confidence < $1.confidence }
    }

    private static func predictedKind(from normalized: String) -> (kind: FinancialTransactionKind, score: Double, label: String)? {
        kindRules
            .filter { normalized.contains($0.text) }
            .max { $0.score < $1.score }
            .map { ($0.kind, $0.score, $0.label) }
    }

    private static func learnedPrediction(for normalized: String, history: [ExpenseTransaction]) -> FinanceInputPrediction? {
        let key = FinanceCategoryClassifier.merchantKey(from: normalized)
        guard key.count >= 3 else { return nil }
        let matches = history
            .filter { FinanceCategoryClassifier.merchantKey(from: FinanceCategoryClassifier.normalizedText($0.title)) == key }
            .sorted { $0.date > $1.date }
        guard !matches.isEmpty else { return nil }

        let topKind = Dictionary(grouping: matches, by: \.kind).mapValues(\.count).max { $0.value < $1.value }
        let topCategory = Dictionary(grouping: matches, by: \.category).mapValues(\.count).max { $0.value < $1.value }
        guard let topKind, let topCategory else { return nil }

        let recentAmounts = matches.prefix(5).map(\.amount).sorted()
        let medianAmount = median(recentAmounts)
        let confidence = min(0.96, 0.66 + Double(min(matches.count, 5)) * 0.06)

        return FinanceInputPrediction(
            kind: topKind.key,
            category: topCategory.key,
            suggestedAmount: medianAmount,
            confidence: confidence,
            reason: "Learned from \(matches.count) similar \(matches.count == 1 ? "entry" : "entries")"
        )
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }
}

enum FinanceCategoryClassifier {
    private struct KeywordRule {
        let text: String
        let score: Double
        let label: String

        init(_ text: String, score: Double, label: String? = nil) {
            self.text = text
            self.score = score
            self.label = label ?? text.capitalized
        }
    }

    private static let expenseRules: [(FinancialCategory, [KeywordRule])] = [
        (.groceries, [
            KeywordRule("woolworths", score: 0.92, label: "Woolworths"),
            KeywordRule("woolies", score: 0.9, label: "Woolies"),
            KeywordRule("coles", score: 0.92, label: "Coles"),
            KeywordRule("aldi", score: 0.92, label: "ALDI"),
            KeywordRule("costco", score: 0.86, label: "Costco"),
            KeywordRule("iga", score: 0.86, label: "IGA"),
            KeywordRule("supermarket", score: 0.78),
            KeywordRule("groceries", score: 0.76),
            KeywordRule("grocery", score: 0.74),
            KeywordRule("market", score: 0.42)
        ]),
        (.dining, [
            KeywordRule("uber eats", score: 0.96, label: "Uber Eats"),
            KeywordRule("doordash", score: 0.96, label: "DoorDash"),
            KeywordRule("menulog", score: 0.92, label: "Menulog"),
            KeywordRule("mcdonald", score: 0.88, label: "McDonald's"),
            KeywordRule("kfc", score: 0.88, label: "KFC"),
            KeywordRule("pizza", score: 0.78),
            KeywordRule("restaurant", score: 0.78),
            KeywordRule("takeaway", score: 0.74),
            KeywordRule("cafe", score: 0.72),
            KeywordRule("coffee", score: 0.72),
            KeywordRule("bubble tea", score: 0.72),
            KeywordRule("lunch", score: 0.54),
            KeywordRule("bar", score: 0.5)
        ]),
        (.transport, [
            KeywordRule("opal", score: 0.92, label: "Opal"),
            KeywordRule("parking", score: 0.86),
            KeywordRule("petrol", score: 0.84),
            KeywordRule("fuel", score: 0.84),
            KeywordRule("train", score: 0.76),
            KeywordRule("metro", score: 0.74),
            KeywordRule("bus", score: 0.72),
            KeywordRule("taxi", score: 0.72),
            KeywordRule("uber", score: 0.58, label: "Uber"),
            KeywordRule("car", score: 0.5)
        ]),
        (.home, [
            KeywordRule("rent", score: 0.92),
            KeywordRule("mortgage", score: 0.92),
            KeywordRule("electricity", score: 0.88),
            KeywordRule("internet", score: 0.82),
            KeywordRule("nbn", score: 0.82, label: "NBN"),
            KeywordRule("water", score: 0.78),
            KeywordRule("power", score: 0.76),
            KeywordRule("phone", score: 0.68),
            KeywordRule("utility", score: 0.68)
        ]),
        (.education, [
            KeywordRule("tuition", score: 0.9),
            KeywordRule("school", score: 0.86),
            KeywordRule("textbook", score: 0.84),
            KeywordRule("course", score: 0.8),
            KeywordRule("lesson", score: 0.78),
            KeywordRule("uniform", score: 0.72),
            KeywordRule("study", score: 0.66),
            KeywordRule("book", score: 0.54)
        ]),
        (.health, [
            KeywordRule("chemist warehouse", score: 0.96, label: "Chemist Warehouse"),
            KeywordRule("pharmacy", score: 0.88),
            KeywordRule("chemist", score: 0.86),
            KeywordRule("doctor", score: 0.86),
            KeywordRule("dental", score: 0.84),
            KeywordRule("clinic", score: 0.82),
            KeywordRule("hospital", score: 0.82),
            KeywordRule("medical", score: 0.76),
            KeywordRule("medicine", score: 0.72)
        ]),
        (.savings, [
            KeywordRule("emergency fund", score: 0.95),
            KeywordRule("savings", score: 0.9),
            KeywordRule("saving", score: 0.84),
            KeywordRule("deposit", score: 0.68)
        ])
    ]

    static func category(for title: String, kind: FinancialTransactionKind) -> FinancialCategory {
        suggestion(for: title, kind: kind, amount: nil, history: []).category
    }

    static func suggestion(
        for title: String,
        kind: FinancialTransactionKind,
        amount: Double?,
        history: [ExpenseTransaction]
    ) -> FinanceCategorySuggestion {
        switch kind {
        case .income:
            return FinanceCategorySuggestion(category: .income, confidence: 1, reason: "Income transaction")
        case .expense:
            let normalized = normalizedText(title)
            guard !normalized.isEmpty else {
                return FinanceCategorySuggestion(category: .groceries, confidence: 0.35, reason: "Default category")
            }

            if let learned = learnedSuggestion(for: normalized, history: history) {
                return learned
            }

            var scores: [FinancialCategory: (score: Double, label: String)] = [:]
            for (category, rules) in expenseRules {
                for rule in rules where normalized.contains(rule.text) {
                    let current = scores[category]?.score ?? 0
                    scores[category] = (current + rule.score, rule.label)
                }
            }

            if normalized.contains("uber eats") {
                scores[.transport] = nil
            }
            if let amount, amount >= 900, normalized.contains("rent") || normalized.contains("mortgage") {
                scores[.home] = ((scores[.home]?.score ?? 0) + 0.2, scores[.home]?.label ?? "large home payment")
            }

            guard let best = scores.max(by: { $0.value.score < $1.value.score }) else {
                return FinanceCategorySuggestion(category: .other, confidence: 0.45, reason: "No strong match")
            }

            let confidence = min(0.95, max(0.52, best.value.score))
            return FinanceCategorySuggestion(
                category: best.key,
                confidence: confidence,
                reason: "Matched \(best.value.label)"
            )
        }
    }

    private static func learnedSuggestion(for normalized: String, history: [ExpenseTransaction]) -> FinanceCategorySuggestion? {
        let key = merchantKey(from: normalized)
        guard key.count >= 3 else { return nil }
        let matches = history.filter {
            $0.kind == .expense
                && $0.category != .other
                && merchantKey(from: normalizedText($0.title)) == key
        }
        guard !matches.isEmpty else { return nil }

        let counts = Dictionary(grouping: matches, by: \.category).mapValues(\.count)
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        let ratio = Double(top.value) / Double(matches.count)
        guard top.value >= 2 || ratio >= 0.67 else { return nil }

        return FinanceCategorySuggestion(
            category: top.key,
            confidence: min(0.96, 0.7 + Double(top.value) * 0.06),
            reason: "Learned from \(top.value) past \(top.value == 1 ? "entry" : "entries")"
        )
    }

    static func merchantKey(from normalized: String) -> String {
        let genericWords: Set<String> = [
            "the", "and", "pty", "ltd", "store", "shop", "online", "payment",
            "purchase", "card", "debit", "visa", "mastercard", "au", "australia"
        ]
        return normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.allSatisfy(\.isNumber) && !genericWords.contains($0) }
            .prefix(3)
            .joined(separator: " ")
    }

    static func normalizedText(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(AppStyle.Typography.section)
            .foregroundStyle(AppStyle.Palette.textPrimary)
    }
}

private struct FinancePredictionRow: View {
    let prediction: FinanceInputPrediction
    let currency: (Double) -> String
    let canApplyAmount: Bool
    let onApplyAmount: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: prediction.kind == .income ? "arrow.down.circle.fill" : FinancePalette.symbol(for: prediction.category))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FinancePalette.grape)
                .frame(width: 28, height: 28)
                .background(FinancePalette.grapeMist, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Suggested")
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textPrimary)

                HStack(spacing: 6) {
                    predictionChip(prediction.kind.rawValue)
                    predictionChip(prediction.category.rawValue)
                }

                Text(prediction.reason)
                    .font(AppStyle.Typography.tiny)
                    .foregroundStyle(AppStyle.Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            if let amount = prediction.suggestedAmount, canApplyAmount {
                Button {
                    onApplyAmount()
                } label: {
                    Text(currency(amount))
                        .lineLimit(1)
                }
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(FinancePalette.grape)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(FinancePalette.grapeMist, in: Capsule())
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppStyle.Palette.primarySoft.opacity(0.48))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppStyle.Palette.primary.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func predictionChip(_ text: String) -> some View {
        Text(text)
            .font(AppStyle.Typography.tiny)
            .foregroundStyle(AppStyle.Palette.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(AppStyle.Palette.surface.opacity(0.74), in: Capsule())
    }
}

private struct SavingsGoalProgressView: View {
    let goal: SavingsGoal
    let monthlyNet: Double
    let currency: (Double) -> String
    let percent: (Double) -> String

    private var monthlyContribution: Double {
        max(monthlyNet, 0)
    }

    private var projectedSavedAmount: Double {
        min(goal.currentAmount + monthlyContribution, goal.targetAmount)
    }

    private var progress: Double {
        min(projectedSavedAmount / max(goal.targetAmount, 1), 1)
    }

    private var remaining: Double {
        max(goal.targetAmount - projectedSavedAmount, 0)
    }

    private var monthsRemaining: Int {
        let months = Calendar.current.dateComponents([.month], from: .now, to: effectiveTargetDate).month ?? 0
        return max(months, 1)
    }

    private var effectiveTargetDate: Date {
        goal.targetDate ?? Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
    }

    private var requiredMonthlySaving: Double {
        remaining / Double(max(monthsRemaining, 1))
    }

    private var statusText: String {
        guard remaining > 0 else { return "Goal reached. Set a new target when ready." }
        if monthlyNet < 0 {
            return "Spending is above income this month."
        }
        if monthlyNet >= requiredMonthlySaving {
            return "On track. \(currency(requiredMonthlySaving)) per month keeps this goal moving."
        }
        let shortfall = requiredMonthlySaving - max(monthlyNet, 0)
        return "\(currency(shortfall)) more per month is needed to stay on track."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(AppStyle.Typography.bodyStrong)
                        .foregroundStyle(Color.white)

                    Text("\(currency(projectedSavedAmount)) of \(currency(goal.targetAmount))")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.76))
                }

                Spacer()

                Text(percent(progress))
                    .font(AppStyle.Typography.titleM.monospacedDigit())
                    .foregroundStyle(Color.white)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.20))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, FinancePalette.grapeMist],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 13)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("This month")
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(Color.white.opacity(0.66))
                    Text(currency(monthlyContribution))
                        .font(AppStyle.Typography.label.monospacedDigit())
                        .foregroundStyle(Color.white)
                }

                Spacer()

                VStack(alignment: .center, spacing: 3) {
                    Text("Needed / month")
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(Color.white.opacity(0.66))
                    Text(currency(requiredMonthlySaving))
                        .font(AppStyle.Typography.label.monospacedDigit())
                        .foregroundStyle(Color.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Target date")
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(Color.white.opacity(0.66))
                    Text(effectiveTargetDate.formatted(.dateTime.month().day().year()))
                        .font(AppStyle.Typography.label)
                        .foregroundStyle(Color.white)
                }
            }

            Text(statusText)
                .font(AppStyle.Typography.caption)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            Text("Progress includes saved so far plus this month's positive cash flow.")
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FinancePalette.grapeDeep,
                            FinancePalette.grape,
                            FinancePalette.grapeMid
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: FinancePalette.grape.opacity(0.22), radius: 16, x: 0, y: 9)
    }
}

private struct GoalEditor: View {
    @Binding var goalTitle: String
    @Binding var goalTargetText: String
    @Binding var goalCurrentText: String
    @Binding var goalTargetDate: Date

    let actionTitle: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            TextField("Goal name", text: $goalTitle)
                .glassInputField()
            TextField("Target amount (AUD)", text: $goalTargetText)
                .keyboardType(.decimalPad)
                .glassInputField()
            TextField("Saved so far (AUD)", text: $goalCurrentText)
                .keyboardType(.decimalPad)
                .glassInputField()

            AppDateSelector(
                selection: $goalTargetDate,
                title: "Target date",
                tint: FinancePalette.grape,
                quickOptions: [
                    .months(3, label: "3 mo"),
                    .months(6, label: "6 mo"),
                    .months(12, label: "1 yr"),
                    .months(18, label: "18 mo")
                ],
                startsExpanded: true
            )

            Button(actionTitle, action: onSave)
                .buttonStyle(.borderedProminent)
                .tint(FinancePalette.grape)
                .font(AppStyle.Typography.label)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .glassPanel(cornerRadius: 24, strokeOpacity: 0.9)
    }
}

private struct FinanceCategoryPicker: View {
    @Binding var selection: FinancialCategory
    let categories: [FinancialCategory]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(categories) { category in
                    categoryButton(category)
                }
            }
        }
    }

    private func categoryButton(_ category: FinancialCategory) -> some View {
        let isSelected = selection == category
        let color = FinancePalette.color(for: category)

        return Button {
            selection = category
        } label: {
            HStack(spacing: 8) {
                Image(systemName: FinancePalette.symbol(for: category))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : color)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? color : color.opacity(0.14))
                    )

                Text(category.rawValue)
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(isSelected ? Color.white : AppStyle.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? color : AppStyle.Palette.surface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(color.opacity(isSelected ? 0 : 0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FinanceStatTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)
            Text(value)
                .font(AppStyle.Typography.bodyStrong.monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPanel(cornerRadius: 22, strokeOpacity: 0.88)
    }
}

private struct CashFlowMonth: Identifiable {
    var id: String { label }
    let label: String
    let income: Double
    let expense: Double

    var net: Double {
        income - expense
    }
}

private struct ComboCashFlowChart: View {
    let months: [CashFlowMonth]
    let currency: (Double) -> String

    private var maxBarValue: Double {
        max(months.map { max($0.income, $0.expense) }.max() ?? 1, 1)
    }

    private var maxNetMagnitude: Double {
        max(months.map { abs($0.net) }.max() ?? 1, 1)
    }

    private var latestNet: Double {
        months.last?.net ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                chartLegend("Income", color: FinancePalette.income)
                chartLegend("Spending", color: FinancePalette.expense)
                chartLegend("Net", color: FinancePalette.grape)
                Spacer(minLength: 0)
                Text("\(latestNet >= 0 ? "+" : "")\(currency(latestNet))")
                    .font(AppStyle.Typography.caption.monospacedDigit())
                    .foregroundStyle(latestNet >= 0 ? FinancePalette.income : FinancePalette.expense)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            ZStack(alignment: .top) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(months) { month in
                        VStack(spacing: 8) {
                            HStack(alignment: .bottom, spacing: 4) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(FinancePalette.income.gradient)
                                    .frame(height: barHeight(month.income))
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(FinancePalette.expense.gradient)
                                    .frame(height: barHeight(month.expense))
                            }
                            .frame(height: 112, alignment: .bottom)

                            Text(month.label)
                                .font(AppStyle.Typography.tiny)
                                .foregroundStyle(AppStyle.Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                NetLineOverlay(months: months, maxMagnitude: maxNetMagnitude)
                    .frame(height: 112)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func chartLegend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)
        }
    }

    private func barHeight(_ value: Double) -> CGFloat {
        guard value > 0 else { return 3 }
        return CGFloat(max(value / maxBarValue, 0.04)) * 112
    }
}

private struct NetLineOverlay: View {
    let months: [CashFlowMonth]
    let maxMagnitude: Double

    var body: some View {
        GeometryReader { proxy in
            let points = netPoints(in: proxy.size)

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(FinancePalette.grape, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                Path { path in
                    let y = proxy.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(AppStyle.Palette.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(AppStyle.Palette.surface)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(FinancePalette.grape, lineWidth: 2))
                        .position(point)
                }
            }
        }
    }

    private func netPoints(in size: CGSize) -> [CGPoint] {
        guard !months.isEmpty else { return [] }
        let step = size.width / CGFloat(months.count)
        return months.enumerated().map { index, month in
            let x = step * CGFloat(index) + step / 2
            let ratio = CGFloat(month.net / max(maxMagnitude, 1))
            let y = size.height / 2 - ratio * size.height * 0.42
            return CGPoint(x: x, y: y)
        }
    }
}

private struct CategorySpendRow: View {
    let category: FinancialCategory
    let amount: Double
    let delta: Double
    let maxAmount: Double
    let color: Color
    let currency: (Double) -> String

    private var deltaText: String {
        if abs(delta) < 1 {
            return "Flat vs last month"
        }
        return "\(delta > 0 ? "Up" : "Down") \(currency(abs(delta))) vs last month"
    }

    private var deltaColor: Color {
        if abs(delta) < 1 { return AppStyle.Palette.textSecondary }
        return delta > 0 ? FinancePalette.expense : FinancePalette.income
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: FinancePalette.symbol(for: category))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 26, height: 26)
                    .background(color.opacity(0.14), in: Circle())

                Text(category.rawValue)
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                Spacer()
                Text(currency(amount))
                    .font(AppStyle.Typography.caption.monospacedDigit())
                    .foregroundStyle(AppStyle.Palette.textSecondary)
            }

            HStack {
                Spacer(minLength: 34)
                Text(deltaText)
                    .font(AppStyle.Typography.tiny)
                    .foregroundStyle(deltaColor)
                Spacer()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppStyle.Palette.surfaceMuted)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: proxy.size.width * max(amount / max(maxAmount, 1), 0.04))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct TransactionEditorSheet: View {
    let transaction: ExpenseTransaction
    let currency: (Double) -> String
    let onSave: (String, Double, FinancialTransactionKind, FinancialCategory, Date) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var amountText: String
    @State private var kind: FinancialTransactionKind
    @State private var category: FinancialCategory
    @State private var date: Date

    init(
        transaction: ExpenseTransaction,
        currency: @escaping (Double) -> String,
        onSave: @escaping (String, Double, FinancialTransactionKind, FinancialCategory, Date) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.currency = currency
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: transaction.title)
        _amountText = State(initialValue: Self.amountString(transaction.amount))
        _kind = State(initialValue: transaction.kind)
        _category = State(initialValue: transaction.category)
        _date = State(initialValue: transaction.date)
    }

    private var availableCategories: [FinancialCategory] {
        kind == .income ? [.income] : FinancialCategory.allCases.filter { $0 != .income }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    Picker("Type", selection: $kind) {
                        ForEach(FinancialTransactionKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        category = newKind == .income ? .income : .groceries
                    }

                    TextField("Title", text: $title)
                        .glassInputField()

                    TextField("Amount in AUD", text: $amountText)
                        .keyboardType(.decimalPad)
                        .glassInputField()

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .font(AppStyle.Typography.label)
                        .padding(12)
                        .background(AppStyle.Palette.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    FinanceCategoryPicker(selection: $category, categories: availableCategories)

                    Text("Current value: \(currency(transaction.amount))")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)

                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Transaction", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .font(AppStyle.Typography.label)
                }
                .padding(20)
            }
            .background(AppStyle.Palette.canvas.ignoresSafeArea())
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let amount = Double(amountText), amount > 0 else { return }
                        onSave(title, amount, kind, category, date)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(amountText) == nil)
                }
            }
        }
    }

    private static func amountString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct TransactionRow: View {
    let item: ExpenseTransaction
    let currency: (Double) -> String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(FinancePalette.color(for: item.category).opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: FinancePalette.symbol(for: item.category))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FinancePalette.color(for: item.category))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(AppStyle.Typography.bodyStrong)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                Text("\(item.category.rawValue) • \(item.date.formatted(.dateTime.month().day()))")
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)
            }

            Spacer()

            Text("\(item.kind == .income ? "+" : "-")\(currency(item.amount))")
                .font(AppStyle.Typography.bodyStrong.monospacedDigit())
                .foregroundStyle(item.kind == .income ? FinancePalette.income : FinancePalette.expense)
        }
    }
}


#Preview {
    NavigationStack {
        ExpenseLedgerView()
            .environmentObject(AppState())
    }
}
