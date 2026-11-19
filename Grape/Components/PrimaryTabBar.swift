import SwiftUI

struct PrimaryTabBar: View {
    @Binding var selectedTab: AppSection

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppSection.allCases) { tab in
                let isSelected = selectedTab == tab

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 7) {
                        AssetCircleIcon(
                            assetName: tab.assetName,
                            iconSize: isSelected ? 24 : 22,
                            circleSize: isSelected ? 50 : 44,
                            circleColor: isSelected ? AppStyle.Palette.primary : AppStyle.Palette.surfaceMuted.opacity(0.8),
                            iconColor: .white, // Let the original icon colors shine through
                            iconScale: isSelected ? 1.26 : 1.18
                        )
                        .shadow(color: isSelected ? AppStyle.Palette.primary.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)

                        Text(tab.title)
                            .font(AppStyle.Typography.caption)
                            .foregroundStyle(isSelected ? AppStyle.Palette.textPrimary : AppStyle.Palette.textSecondary)
                            .fontWeight(isSelected ? .bold : .medium)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppStyle.Palette.surface)
                .shadow(color: AppStyle.Palette.primary.opacity(0.2), radius: 20, x: 0, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(AppStyle.Palette.primary.opacity(0.2), lineWidth: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
