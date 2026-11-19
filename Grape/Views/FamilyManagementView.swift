import SwiftUI
import UIKit

struct FamilyManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var roleError = ""
    @State private var usernameDraft = ""
    @State private var displayNameDraft = ""
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    SurfaceCard(title: "My Profile", iconAssetName: "AppIcon") {
                        VStack(spacing: 10) {
                            TextField("Username", text: $usernameDraft)
                                .glassInputField()

                            TextField("Display Name in Family", text: $displayNameDraft)
                                .glassInputField()

                            HStack {
                                Text("Current Role: \(appState.currentMembership?.role.rawValue ?? "-")")
                                    .font(AppStyle.Typography.caption)
                                    .foregroundStyle(AppStyle.Palette.textSecondary)
                                Spacer()
                            }

                            Button("Save Profile") {
                                roleError = appState.updateCurrentUsername(usernameDraft) ?? ""
                                if roleError.isEmpty {
                                    roleError = appState.updateCurrentDisplayName(displayNameDraft) ?? ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppStyle.Palette.primary)
                        }
                    }

                    SurfaceCard(title: appState.currentFamily?.name ?? "Family", iconAssetName: "One Family") {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Family ID")
                                    .font(.caption)
                                    .foregroundStyle(AppStyle.Palette.textSecondary)
                                Text(appState.currentFamily?.inviteCode ?? "-")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppStyle.Palette.primary)
                            }
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = appState.currentFamily?.inviteCode ?? ""
                            }
                            .buttonStyle(.bordered)
                            .tint(AppStyle.Palette.primary)
                        }

                        Text("Share this Family ID so members can join your household only.")
                            .font(AppStyle.Typography.caption)
                            .foregroundStyle(AppStyle.Palette.textSecondary)
                    }

                    SurfaceCard(title: "Member Roles", iconAssetName: "One Family", trailingText: appState.currentMembership?.role.rawValue ?? "-") {
                        if !roleError.isEmpty {
                            Text(roleError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        ForEach(Array(appState.familyMembers.enumerated()), id: \.element.id) { index, member in
                            memberRow(member)

                            if index != appState.familyMembers.count - 1 {
                                Divider().overlay(AppStyle.Palette.separator)
                            }
                        }

                        if appState.currentUserCanManageMembers {
                            Text("Owner/Admin can change roles and remove members. At least one Owner must remain.")
                                .font(AppStyle.Typography.caption)
                                .foregroundStyle(AppStyle.Palette.textSecondary)
                                .padding(.top, 4)
                        }
                    }

                    if appState.currentUserCanManageMembers {
                        SurfaceCard(title: "Join Requests", iconAssetName: "Communication", trailingText: "\(appState.pendingJoinRequests.count)") {
                            if appState.pendingJoinRequests.isEmpty {
                                Text("No pending applications.")
                                    .font(AppStyle.Typography.caption)
                                    .foregroundStyle(AppStyle.Palette.textSecondary)
                            } else {
                                ForEach(Array(appState.pendingJoinRequests.enumerated()), id: \.element.id) { index, request in
                                    requestRow(request)
                                    if index != appState.pendingJoinRequests.count - 1 {
                                        Divider().overlay(AppStyle.Palette.separator)
                                    }
                                }
                            }
                        }
                    }

                    SurfaceCard(title: "Data", iconAssetName: "Expense") {
                        Text("Cloud sync: \(appState.syncStatus.message)")
                            .font(AppStyle.Typography.caption)
                            .foregroundStyle(AppStyle.Palette.textSecondary)

                        Text("Reset removes all local families, members, tasks and messages on this device.")
                            .font(AppStyle.Typography.caption)
                            .foregroundStyle(AppStyle.Palette.textSecondary)

                        Button("Reset Local Data") {
                            showResetAlert = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(AppStyle.Palette.canvas.ignoresSafeArea())
            .navigationTitle("Family Management")
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
            .onAppear {
                usernameDraft = appState.currentUser?.username ?? ""
                displayNameDraft = appState.currentMembership?.displayName ?? ""
            }
            .alert("Reset local data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    appState.resetToSeedData()
                }
            } message: {
                Text("This action cannot be undone on this device.")
            }
        }
    }

    private func memberRow(_ member: FamilyMembership) -> some View {
        HStack(spacing: 12) {
            Image(member.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(member.role.rawValue)
                    .font(.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)
            }

            Spacer()

            if appState.currentUserCanManageMembers {
                Menu {
                    ForEach(FamilyRole.allCases) { role in
                        Button(role.rawValue) {
                            roleError = appState.updateMemberRole(memberID: member.id, to: role) ?? ""
                        }
                    }

                    if member.id != appState.currentMembership?.id {
                        Divider()

                        Button(role: .destructive) {
                            roleError = appState.removeMember(memberID: member.id) ?? ""
                        } label: {
                            Text("Remove Member")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(AppStyle.Palette.primary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func requestRow(_ request: FamilyJoinRequest) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(request.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(request.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("Requested role: \(request.requestedRole.rawValue)")
                    .font(.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)
            }

            Spacer()

            VStack(spacing: 6) {
                Button("Approve") {
                    roleError = appState.approveJoinRequest(requestID: request.id) ?? ""
                }
                .font(.caption2)
                .buttonStyle(.borderedProminent)
                .tint(AppStyle.Palette.accent)

                Button("Reject") {
                    roleError = appState.rejectJoinRequest(requestID: request.id) ?? ""
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    FamilyManagementView()
        .environmentObject(AppState())
}
