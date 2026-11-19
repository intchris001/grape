import SwiftUI
import UIKit

struct OneFamilyHubView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showFamilyManager = false
    @State private var showFavorites = false
    @State private var activeNotice: FeatureNotice?
    @State private var choreDraw: ChoreDrawResult?
    @State private var completedDrawIDs: Set<UUID> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                headerSection
                choreDrawCard
                featureRows
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
        .navigationTitle("Family Hub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppStyle.Palette.primary)
                }
                .accessibilityLabel("Close")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFamilyManager = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppStyle.Palette.primary)
                }
            }
        }
        .sheet(isPresented: $showFamilyManager) {
            FamilyManagementView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFavorites) {
            SavedChatMessagesView()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(item: $activeNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            Image("One Family")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)

            Text("One family, one love.")
                .font(AppStyle.Typography.titleM)
                .foregroundStyle(AppStyle.Palette.primary)

            Text("Let's create beautiful memories together.")
                .font(AppStyle.Typography.label)
                .foregroundStyle(AppStyle.Palette.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach(appState.familyMembers) { member in
                    FamilyMemberAvatar(member: member)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassPanel(cornerRadius: 24)
    }

    private var choreDrawCard: some View {
        SurfaceCard(title: "Chore Draw", iconAssetName: "Task") {
            VStack(spacing: 14) {
                if let choreDraw {
                    choreResultView(choreDraw)
                } else {
                    choreEmptyState
                }

                HStack(spacing: 10) {
                    Button {
                        drawChore()
                    } label: {
                        Label(choreDraw == nil ? "Draw a Chore" : "Draw Again", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppStyle.Palette.primary)
                    .font(AppStyle.Typography.label)
                    .disabled(appState.familyMembers.isEmpty)

                    if let choreDraw {
                        Button {
                            addDrawToTasks(choreDraw)
                        } label: {
                            Image(systemName: completedDrawIDs.contains(choreDraw.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                                .frame(width: 46, height: 38)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppStyle.Palette.accent)
                        .disabled(completedDrawIDs.contains(choreDraw.id))
                        .accessibilityLabel(completedDrawIDs.contains(choreDraw.id) ? "Added to Task Board" : "Add to Task Board")
                    }
                }
            }
        }
    }

    private var choreEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppStyle.Palette.primary)
                .frame(width: 54, height: 54)
                .background(AppStyle.Palette.primarySoft.opacity(0.78), in: Circle())

            Text(appState.familyMembers.isEmpty ? "Add family members first." : "Let the family decide the next chore.")
                .font(AppStyle.Typography.label)
                .foregroundStyle(AppStyle.Palette.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func choreResultView(_ draw: ChoreDrawResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(draw.member.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .background(AppStyle.Palette.primarySoft.opacity(0.68))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(draw.member.displayName)
                        .font(AppStyle.Typography.section)
                        .foregroundStyle(AppStyle.Palette.textPrimary)
                        .lineLimit(1)

                    Text("gets today's chore")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: draw.chore.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppStyle.Palette.primary)
                    .frame(width: 34, height: 34)
                    .background(AppStyle.Palette.primarySoft.opacity(0.74), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(draw.chore.title)
                        .font(AppStyle.Typography.bodyStrong)
                        .foregroundStyle(AppStyle.Palette.textPrimary)

                    Text("+10 family points")
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppStyle.Palette.surfaceMuted.opacity(0.72))
            )
        }
    }

    private var featureRows: some View {
        VStack(spacing: 12) {
            actionRow(
                title: "Favorites",
                systemImage: "bookmark"
            ) {
                showFavorites = true
            }

            actionRow(
                title: "Family Settings",
                systemImage: "gearshape"
            ) {
                showFamilyManager = true
            }

            actionRow(
                title: "Invite Members",
                systemImage: "person.badge.plus"
            ) {
                UIPasteboard.general.string = appState.currentFamily?.inviteCode ?? ""
                activeNotice = FeatureNotice(
                    title: "Family ID Copied",
                    message: "Share this code with your family: \(appState.currentFamily?.inviteCode ?? "-")"
                )
            }
        }
    }

    private func actionRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Palette.primarySoft)
                        .frame(width: 34, height: 34)
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.Palette.primary)
                }

                Text(title)
                    .font(AppStyle.Typography.bodyStrong)
                    .foregroundStyle(AppStyle.Palette.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppStyle.Palette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppStyle.Palette.surface.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppStyle.Palette.glassHighlight.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: AppStyle.Palette.glassShadow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func drawChore() {
        guard let member = appState.familyMembers.randomElement(),
              let chore = ChoreOption.allCases.randomElement() else {
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            choreDraw = ChoreDrawResult(member: member, chore: chore)
        }
    }

    private func addDrawToTasks(_ draw: ChoreDrawResult) {
        appState.addTask(title: draw.chore.title, assigneeMemberID: draw.member.id, dueDate: .now)
        completedDrawIDs.insert(draw.id)
        activeNotice = FeatureNotice(
            title: "Added to Task Board",
            message: "\(draw.chore.title) is assigned to \(draw.member.displayName)."
        )
    }
}

private struct ChoreDrawResult: Identifiable, Equatable {
    let id = UUID()
    let member: FamilyMembership
    let chore: ChoreOption
}

private struct ChoreOption: Equatable {
    let id: String
    let title: String
    let systemImage: String

    static let allCases: [ChoreOption] = [
        ChoreOption(id: "washDishes", title: "Wash the dishes", systemImage: "fork.knife"),
        ChoreOption(id: "takeOutTrash", title: "Take out the trash", systemImage: "trash"),
        ChoreOption(id: "tidyLivingRoom", title: "Tidy the living room", systemImage: "sofa"),
        ChoreOption(id: "foldLaundry", title: "Fold the laundry", systemImage: "tshirt"),
        ChoreOption(id: "wipeTable", title: "Wipe the table", systemImage: "sparkles"),
        ChoreOption(id: "waterPlants", title: "Water the plants", systemImage: "leaf")
    ]
}

private struct SavedChatMessagesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if appState.savedChatMessages.isEmpty {
                    emptyState
                        .padding(.top, 80)
                        .padding(.horizontal, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.savedChatMessages) { saved in
                            savedMessageRow(saved)
                        }
                    }
                    .padding(20)
                }
            }
            .background(AppStyle.Palette.canvasGradient.ignoresSafeArea())
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.headline.weight(.semibold))
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppStyle.Palette.primary)
                .frame(width: 64, height: 64)
                .background(AppStyle.Palette.primarySoft.opacity(0.72), in: Circle())

            Text("No favorites yet")
                .font(AppStyle.Typography.label)
                .foregroundStyle(AppStyle.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func savedMessageRow(_ saved: SavedChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(initials(from: saved.senderName))
                    .font(AppStyle.Typography.tiny)
                    .foregroundStyle(AppStyle.Palette.primary)
                    .frame(width: 34, height: 34)
                    .background(AppStyle.Palette.primarySoft.opacity(0.82), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(saved.senderName)
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)

                    Text(saved.text)
                        .font(AppStyle.Typography.label)
                        .foregroundStyle(AppStyle.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Menu {
                    Button {
                        UIPasteboard.general.string = saved.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        appState.deleteSavedChatMessage(id: saved.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(AppStyle.Palette.primary)
                }
            }

            Text("Saved \(saved.savedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)
        }
        .padding(14)
        .background(AppStyle.Palette.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppStyle.Palette.glassHighlight.opacity(0.78), lineWidth: 1)
        )
    }

    private func initials(from name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(name.prefix(1)).uppercased() : String(letters).uppercased()
    }
}

private struct FeatureNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func comingSoon(feature: String) -> FeatureNotice {
        FeatureNotice(
            title: feature,
            message: "This module is being built next."
        )
    }
}

#Preview {
    NavigationStack {
        OneFamilyHubView()
            .environmentObject(AppState())
    }
}
