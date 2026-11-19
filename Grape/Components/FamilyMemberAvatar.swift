import SwiftUI

struct FamilyMemberAvatar: View {
    let member: FamilyMembership

    var body: some View {
        VStack(spacing: 8) {
            Image(member.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .background(AppStyle.Palette.primarySoft.opacity(0.6))
                .clipShape(Circle())

            Text(member.displayName)
                .font(AppStyle.Typography.caption)
                .foregroundStyle(AppStyle.Palette.textPrimary)
                .lineLimit(1)

            Text(member.role.rawValue)
                .font(AppStyle.Typography.tiny)
                .foregroundStyle(AppStyle.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
