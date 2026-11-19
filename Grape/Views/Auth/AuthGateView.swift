import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var appState: AppState

    @State private var isRegisterMode = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorText = ""
    @State private var isSubmitting = false

    private let demoProfiles: [DemoProfile] = [
        .init(name: "Demo Family A", subtitle: "Owner account", email: "tester001@app.com", password: "123456", accent: .blue),
        .init(name: "Demo Family B", subtitle: "Admin account", email: "tester002@app.com", password: "123456", accent: .teal),
        .init(name: "Demo Family C", subtitle: "Child account", email: "tester003@app.com", password: "123456", accent: .orange)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                topHero

                modeTabs

                SurfaceCard(
                    title: isRegisterMode ? "Create Your Account" : "Welcome Back",
                    iconAssetName: isRegisterMode ? "One Family" : "AppIcon"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if isRegisterMode {
                            fieldLabel("Username")
                            TextField("How family sees you", text: $username)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .glassInputField()
                        }

                        fieldLabel("Email")
                        TextField("name@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .glassInputField()

                        fieldLabel("Password")
                        SecureField("At least 6 characters", text: $password)
                            .textInputAutocapitalization(.never)
                            .glassInputField()

                        if !errorText.isEmpty {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(isRegisterMode ? "Register" : "Login") {
                            Task { await submit() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppStyle.Palette.primary)
                        .font(AppStyle.Typography.label)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(!isFormValid || isSubmitting)
                    }
                }

                SurfaceCard(title: "Quick Access", iconAssetName: "AppIcon") {

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tap a profile to sign in instantly.")
                            .font(AppStyle.Typography.caption)
                            .foregroundStyle(AppStyle.Palette.textSecondary)

                        ForEach(demoProfiles) { profile in
                            Button {
                                Task { await quickDemoSignIn(profile) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(profile.accent)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(AppStyle.Typography.label)
                                            .foregroundStyle(AppStyle.Palette.textPrimary)
                                        Text(profile.subtitle)
                                            .font(AppStyle.Typography.caption)
                                            .foregroundStyle(AppStyle.Palette.textSecondary)
                                    }

                                    Spacer(minLength: 8)

                                    Text("Use")
                                        .font(AppStyle.Typography.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(profile.accent, in: Capsule())
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(AppStyle.Palette.surface)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isSubmitting)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [AppStyle.Palette.canvas, AppStyle.Palette.primarySoft.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var isFormValid: Bool {
        if isRegisterMode {
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   email.contains("@") &&
                   password.count >= 6
        } else {
            return email.contains("@") && !password.isEmpty
        }
    }

    private var topHero: some View {
        VStack(spacing: 10) {
            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .padding(10)
                .background(AppStyle.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: AppStyle.Shadow.cardColor, radius: 12, x: 0, y: 6)

            Text("Grape")
                .font(AppStyle.Typography.titleL)
                .foregroundStyle(AppStyle.Palette.textPrimary)

            Text("Family-first planner and communication")
                .font(AppStyle.Typography.label)
                .foregroundStyle(AppStyle.Palette.textSecondary)
        }
    }

    private var modeTabs: some View {
        HStack(spacing: 8) {
            modeButton("Login", active: !isRegisterMode) {
                isRegisterMode = false
                errorText = ""
                username = ""
                password = ""
            }
            modeButton("Register", active: isRegisterMode) {
                isRegisterMode = true
                errorText = ""
                password = ""
            }
        }
    }

    private func modeButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppStyle.Typography.label)
                .foregroundStyle(active ? .white : AppStyle.Palette.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(active ? AppStyle.Palette.primary : AppStyle.Palette.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(AppStyle.Typography.caption)
            .foregroundStyle(AppStyle.Palette.textSecondary)
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        if isRegisterMode {
            errorText = await appState.register(username: username, email: email, password: password) ?? ""
        } else {
            errorText = await appState.login(email: email, password: password) ?? ""
        }

        if errorText.isEmpty {
            password = ""
        }
    }

    private func quickDemoSignIn(_ profile: DemoProfile) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        isRegisterMode = false
        email = profile.email
        password = profile.password
        errorText = await appState.login(email: profile.email, password: profile.password) ?? ""
        if errorText.isEmpty {
            password = ""
        }
    }
}

private struct DemoProfile: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let email: String
    let password: String
    let accent: Color
}

#Preview {
    AuthGateView()
        .environmentObject(AppState())
}
