import SwiftUI

struct TaskItemRow: View {
    let task: TaskRecord
    let assigneeName: String
    var onToggle: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    @State private var bounceAnim = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                AppStyle.Haptic.play(.medium)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.5)) {
                    bounceAnim = true
                    onToggle?()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    bounceAnim = false
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? AppStyle.Palette.accent : AppStyle.Palette.textSecondary.opacity(0.35), lineWidth: 1.8)
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Circle()
                            .fill(AppStyle.Palette.accent)
                            .frame(width: 16, height: 16)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(bounceAnim ? 1.25 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark task as incomplete" : "Mark task as complete")
            .accessibilityHint("Double tap to toggle task completion status")

            Button {
                if let onEdit {
                    AppStyle.Haptic.play(.light)
                    onEdit()
                } else {
                    AppStyle.Haptic.play(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.5)) {
                        bounceAnim = true
                        onToggle?()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        bounceAnim = false
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(AppStyle.Typography.body)
                        .strikethrough(task.isCompleted, color: AppStyle.Palette.textSecondary.opacity(0.45))
                        .foregroundStyle(task.isCompleted ? AppStyle.Palette.textSecondary : AppStyle.Palette.textPrimary)
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                    Text(task.dueDate, format: .dateTime.month().day().hour().minute())
                        .font(AppStyle.Typography.tiny.monospacedDigit())
                        .foregroundStyle(AppStyle.Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Task: \(task.title)")
            .accessibilityValue(task.isCompleted ? "Completed" : "Due \(task.dueDate.formatted(date: .abbreviated, time: .shortened))")

            Text(assigneeName)
                .font(AppStyle.Typography.caption)
                .foregroundStyle(AppStyle.Palette.textSecondary)
                .lineLimit(1)
                .accessibilityHidden(true)

            if let onEdit {
                Button(action: {
                    AppStyle.Haptic.play(.light)
                    onEdit()
                }) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppStyle.Palette.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit task")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }
}
