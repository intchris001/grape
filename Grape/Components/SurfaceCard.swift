import SwiftUI

struct SurfaceCard<Content: View>: View {
    let title: String
    var iconAssetName: String?
    var trailingText: String?
    @ViewBuilder var content: Content

    init(
        title: String,
        iconAssetName: String? = nil,
        trailingText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.iconAssetName = iconAssetName
        self.trailingText = trailingText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if let iconAssetName {
                    AssetCircleIcon(assetName: iconAssetName, iconSize: 20, circleSize: 38, iconScale: 1.1)
                }

                Text(title)
                    .font(AppStyle.Typography.section)
                    .foregroundStyle(AppStyle.Palette.textPrimary)
                    .textCase(.uppercase) // Make headers uppercase for a sharper look

                Spacer()

                if let trailingText {
                    Text(trailingText)
                        .font(AppStyle.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppStyle.Palette.primary, in: Capsule())
                }
            }
            .padding(.bottom, 4)

            content
        }
        .padding(20)
        .glassPanel(cornerRadius: AppStyle.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.Radius.card, style: .continuous)
                .stroke(AppStyle.Palette.primary.opacity(0.3), lineWidth: 2)
        )
    }
}
