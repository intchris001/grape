import SwiftUI

struct AssetCircleIcon: View {
    let assetName: String
    var iconSize: CGFloat = 22
    var circleSize: CGFloat = 44
    var circleColor: Color = AppStyle.Palette.surfaceMuted
    var iconColor: Color = .white
    var iconScale: CGFloat = 1.2

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: circleSize * 0.3, style: .continuous) // Using squircle instead of pure circle
                .fill(circleColor)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    RoundedRectangle(cornerRadius: circleSize * 0.3, style: .continuous)
                        .stroke(AppStyle.Palette.primary.opacity(0.1), lineWidth: 1.5)
                )

            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.25, style: .continuous))
                .scaleEffect(iconScale)
                .colorMultiply(iconColor)
        }
    }
}
