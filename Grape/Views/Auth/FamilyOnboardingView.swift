import SwiftUI

struct FamilyOnboardingView: View {
    @EnvironmentObject private var appState: AppState

    @State private var modeCreate = false
    @State private var familyName = ""
    @State private var inviteCode = ""
    @State private var displayName = ""
    @State private var role: FamilyRole = .parent
    @State private var avatar = SeedData.avatarOptions.first ?? "father"
    @State private var errorText = ""
    @State private var successText = ""

    private var modeSelection: Binding<Bool> {
        Binding(
            get: { modeCreate },
            set: { newValue in
                modeCreate = newValue
                clearStatus()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SurfaceCard(title: "Family Setup", iconAssetName: "One Family") {
                    Text("Join with a Family ID or create a new family.")
                        .font(AppStyle.Typography.label)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }

                if let pendingRequest = appState.currentUserPendingJoinRequest {
                    pendingRequestCard(pendingRequest)
                } else {
                    Picker("Mode", selection: modeSelection) {
                        Text("Join Family").tag(false)
                        Text("Create Family").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .font(AppStyle.Typography.caption)

                    setupForm
                }

                Button("Logout") {
                    appState.logout()
                }
                .font(AppStyle.Typography.label)
                .foregroundStyle(AppStyle.Palette.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(AppStyle.Palette.canvas.ignoresSafeArea())
    }

    private var setupForm: some View {
        SurfaceCard(title: modeCreate ? "Create New Family" : "Join Existing Family", iconAssetName: "One Family") {
            VStack(spacing: 10) {
                if modeCreate {
                    Text("Create a new family space.")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Family name", text: $familyName)
                        .glassInputField()
                } else {
                    Text("Ask an owner or admin for the Family ID.")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Family ID", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .glassInputField()
                }

                TextField("Your display name in family", text: $displayName)
                    .glassInputField()

                if modeCreate {
                    HStack {
                        Text("Your role:")
                            .font(AppStyle.Typography.label)
                            .foregroundStyle(AppStyle.Palette.textSecondary)
                        Spacer()
                        Text("Owner")
                            .font(AppStyle.Typography.label)
                            .foregroundStyle(AppStyle.Palette.primary)
                    }
                } else {
                    Picker("Role", selection: $role) {
                        ForEach(FamilyRole.allCases.filter { $0 != .owner }) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Picker("Avatar", selection: $avatar) {
                    ForEach(SeedData.avatarOptions, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                statusText

                Button(modeCreate ? "Create Family" : "Join Family") {
                    Task {
                        await submit()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppStyle.Palette.primary)
                .font(AppStyle.Typography.label)
                .disabled(isSubmitDisabled)
            }
        }
    }

    private var isSubmitDisabled: Bool {
        if modeCreate {
            return familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func pendingRequestCard(_ request: FamilyJoinRequest) -> some View {
        let family = appState.family(for: request)
        let familyID = family?.inviteCode ?? "-"

        return SurfaceCard(title: "Waiting for Approval", iconAssetName: "One Family") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your join request has been sent. An owner or admin needs to approve it before you can enter this family space.")
                    .font(AppStyle.Typography.label)
                    .foregroundStyle(AppStyle.Palette.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Family ID")
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                    Text(familyID)
                        .font(AppStyle.Typography.titleM)
                        .foregroundStyle(AppStyle.Palette.primary)
                    if let family {
                        Text(family.name)
                            .font(AppStyle.Typography.caption)
                            .foregroundStyle(AppStyle.Palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AppStyle.Palette.surfaceMuted.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Requested role: \(request.requestedRole.rawValue)")
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(AppStyle.Palette.textSecondary)

                statusText

                Button("Cancel Request") {
                    cancelRequest()
                }
                .buttonStyle(.bordered)
                .tint(AppStyle.Palette.primary)
                .font(AppStyle.Typography.label)
            }
        }
    }

    private var statusText: some View {
        Group {
            if !errorText.isEmpty {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !successText.isEmpty {
                Text(successText)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func submit() async {
        errorText = ""
        successText = ""
        if modeCreate {
            if let error = appState.createFamily(
                name: familyName,
                displayName: displayName,
                avatar: avatar
            ) {
                errorText = error
            }
        } else {
            let result = await appState.joinFamily(
                inviteCode: inviteCode,
                displayName: displayName,
                role: role,
                avatar: avatar
            )
            if let result {
                if result.contains("sent") {
                    clearFormAfterJoinRequest()
                } else {
                    errorText = result
                }
            }
        }
    }

    private func cancelRequest() {
        if let error = appState.cancelCurrentJoinRequest() {
            errorText = error
        } else {
            successText = "Join request cancelled."
            modeCreate = false
        }
    }

    private func clearFormAfterJoinRequest() {
        inviteCode = ""
        displayName = ""
        role = .parent
    }

    private func clearStatus() {
        errorText = ""
        successText = ""
    }
}

#Preview {
    FamilyOnboardingView()
        .environmentObject(AppState())
}
