import SwiftUI

// MARK: - Permission Banner View

/// A system-style alert banner shown when Accessibility permissions are not granted.
struct PermissionBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(.systemYellow))
                .symbolRenderingMode(.multicolor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Required")
                    .font(.system(size: 12, weight: .semibold))

                Text("Needs access to read and modify text in other apps.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Open System Settings → Privacy → Accessibility") {
                    AccessibilityHelper.openAccessibilitySettings()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }
}
