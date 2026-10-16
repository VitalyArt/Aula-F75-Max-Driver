import AppKit
import SwiftUI

/// The full operation log: every command, result and error the app records.
struct ActivityLogView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.format("%d entries", model.logLines.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    copyLog()
                } label: {
                    Label(L10n.text("Copy Log"), systemImage: "doc.on.doc")
                }
                .help(L10n.text("Copy the whole log to the clipboard"))
                .disabled(model.logLines.isEmpty)
            }

            LogTextView(lines: model.logLines)
        }
        .padding(.horizontal, PageLayout.horizontalInset)
        .padding(.top, 8)
        .padding(.bottom, PageLayout.bottomClearance)
        .navigationTitle(SidebarPage.activityLog.title)
    }

    private func copyLog() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(model.logLines.joined(separator: "\n"), forType: .string)
    }
}
