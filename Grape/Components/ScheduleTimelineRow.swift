import SwiftUI

struct ScheduleTimelineRow: View {
    let item: ScheduleEntry
    var showTimeline: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showTimeline {
                VStack(spacing: 4) {
                    Circle()
                        .fill(AppStyle.Palette.primary)
                        .frame(width: 7, height: 7)

                    Rectangle()
                        .fill(AppStyle.Palette.primary.opacity(0.25))
                        .frame(width: 1, height: 34)
                }
                .frame(width: 8)
            }

            Text(item.date, format: .dateTime.hour().minute())
                .font(AppStyle.Typography.numericTime)
                .foregroundStyle(AppStyle.Palette.textPrimary)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppStyle.Typography.body)
                    .foregroundStyle(AppStyle.Palette.textPrimary)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppStyle.Typography.tiny)
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}
