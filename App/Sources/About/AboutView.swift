import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 5) {
                Text(AppInfo.name)
                    .font(.system(size: 17, weight: .semibold))
                Text(AppInfo.version)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(AppInfo.copyright)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 300)
    }
}
