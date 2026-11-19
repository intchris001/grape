import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    profileHeader
                    appearanceSection
                    accountSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(AppStyle.Palette.canvas.ignoresSafeArea())
            .navigationTitle("Profile & Settings")
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
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppStyle.Palette.primarySoft)
                    .frame(width: 96, height: 96)
                
                if let avatar = appState.currentMembership?.avatarAssetName {
                    Image(avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(AppStyle.Palette.primary)
                }
            }
            .shadow(color: AppStyle.Shadow.cardColor, radius: 12, x: 0, y: 6)

            VStack(spacing: 4) {
                Text(appState.currentMembership?.displayName ?? appState.currentUser?.username ?? "User")
                    .font(AppStyle.Typography.titleM)
                    .foregroundStyle(AppStyle.Palette.textPrimary)

                Text(appState.currentUser?.email ?? "No Email")
                    .font(AppStyle.Typography.body)
                    .foregroundStyle(AppStyle.Palette.textSecondary)
            }
            
            if let role = appState.currentMembership?.role {
                Text(role.rawValue)
                    .font(AppStyle.Typography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(AppStyle.Palette.primary, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassPanel(cornerRadius: AppStyle.Radius.card)
    }

    private var appearanceSection: some View {
        SurfaceCard(title: "Appearance", iconAssetName: "AppIcon") {
            Toggle(isOn: $isDarkMode) {
                HStack(spacing: 12) {
                    Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                        .font(.title2)
                        .foregroundStyle(isDarkMode ? AppStyle.Palette.primarySoft : AppStyle.Palette.accent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dark Mode")
                            .font(AppStyle.Typography.bodyStrong)
                            .foregroundStyle(AppStyle.Palette.textPrimary)
                        Text(isDarkMode ? "Currently using dark theme" : "Currently using light theme")
                            .font(AppStyle.Typography.caption)
                            .foregroundStyle(AppStyle.Palette.textSecondary)
                    }
                }
            }
            .tint(AppStyle.Palette.primary)
            .padding(.vertical, 8)
        }
    }

    private var accountSection: some View {
        SurfaceCard(title: "Account", iconAssetName: "One Family") {
            VStack(spacing: 16) {
                Button(role: .destructive) {
                    appState.logout()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                        Text("Sign Out")
                            .font(AppStyle.Typography.bodyStrong)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: AppStyle.Radius.capsule))
                }
            }
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(AppState())
}