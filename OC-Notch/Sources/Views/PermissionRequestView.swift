import SwiftUI

struct PermissionRequestView: View {
    let request: OCPermissionRequest
    @Environment(SessionMonitorService.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.promptInnerSpacing) {
            HStack(spacing: DS.Spacing.promptSectionSpacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DS.Colors.accentOrange)
                Text(request.sessionTitle ?? request.sessionID)
                    .font(DS.Typography.promptTitle())
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Text(request.permission)
                    .font(DS.Typography.promptOptionDetail())
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DS.Colors.elevatedSurface)
                    )
            }

            if let description = request.displayDescription {
                Text(description)
                    .font(DS.Typography.promptBodyMono())
                    .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
                    .lineLimit(6)
                    .padding(DS.Spacing.promptSectionSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radii.small, style: .continuous)
                            .fill(DS.Colors.elevatedSurface)
                    )
            }

            HStack(spacing: DS.Spacing.promptSectionSpacing) {
                Button {
                    Task { await monitor.replyPermission(requestID: request.id, reply: .once) }
                } label: {
                    HStack(spacing: DS.Spacing.tightSpacing) {
                        Label("Allow Once", systemImage: "checkmark")
                        Text("⌘Y").dsShortcutBadge()
                    }
                    .font(DS.Typography.promptOption())
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.accentGreen)
                .keyboardShortcut("y", modifiers: .command)

                Button {
                    Task { await monitor.replyPermission(requestID: request.id, reply: .always) }
                } label: {
                    HStack(spacing: DS.Spacing.tightSpacing) {
                        Label("Always", systemImage: "checkmark.circle")
                        Text("⌘A").dsShortcutBadge()
                    }
                    .font(DS.Typography.promptOption())
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("a", modifiers: .command)

                Spacer()

                Button {
                    Task { await monitor.replyPermission(requestID: request.id, reply: .reject) }
                } label: {
                    HStack(spacing: DS.Spacing.tightSpacing) {
                        Label("Reject", systemImage: "xmark")
                        Text("⌘N").dsShortcutBadge()
                    }
                    .font(DS.Typography.promptOption())
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.accentRed)
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .padding(DS.Spacing.promptCardPadding)
    }
}
