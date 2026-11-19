import SwiftUI

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppStyle.Palette.surfaceMuted)
                    .frame(width: 80, height: 80)
                
                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(AppStyle.Palette.primary)
            }
            .padding(.bottom, 8)

            Text(title)
                .font(AppStyle.Typography.titleM)
                .foregroundStyle(AppStyle.Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(AppStyle.Typography.body)
                .foregroundStyle(AppStyle.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(action: {
                    AppStyle.Haptic.play(.medium)
                    action()
                }) {
                    Text(actionTitle)
                        .font(AppStyle.Typography.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppStyle.Palette.primary, in: Capsule())
                }
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .glassPanel(cornerRadius: AppStyle.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(message)")
    }
}

#Preview {
    EmptyStateView(
        iconName: "tray.fill",
        title: "No Items Found",
        message: "There are currently no items matching your criteria. Try adjusting your filters or creating a new item.",
        actionTitle: "Create Item"
    ) {}
}