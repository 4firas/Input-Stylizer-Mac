import SwiftUI

// MARK: - Permission Banner View

/// A prominent warning banner shown when Accessibility permissions are not granted.
/// Appears at the top of the menu bar popover to guide the user.
struct PermissionBannerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Accessibility Required")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("SystemWideStylizer needs Accessibility access to read and modify text in other apps.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                AccessibilityHelper.openAccessibilitySettings()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                    Text("Open System Settings")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Text("Tip: If already enabled, select and remove the app from the settings list using the '—' button, then toggle it back on.")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.55, blue: 0.15),
                            Color(red: 0.90, green: 0.35, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}


