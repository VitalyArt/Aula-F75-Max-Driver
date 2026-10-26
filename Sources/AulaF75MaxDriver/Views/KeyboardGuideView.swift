import SwiftUI

/// A static, offline reference. The picker never changes the device mode.
struct KeyboardGuideView: View {
    @State private var mode = "windows"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.text("guide.intro"))
                    .font(.title3)
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(L10n.text("guide.mode"), selection: $mode) {
                            Text("Windows").tag("windows")
                            Text("Mac").tag("mac")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 260)
                        CardFootnote(L10n.text("guide.mode_note"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(L10n.text("guide.mode"), systemImage: "keyboard")
                }
                ForEach(KeyboardGuideCatalog.groups) { group in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.text(group.note))
                                .foregroundStyle(group.id == "guide.reset_section" ? Color.orange : Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(group.entries.filter { $0.mode == "all" || $0.mode == mode }) { entry in
                                guideRow(entry)
                                if entry.id != group.entries.last(where: { $0.mode == "all" || $0.mode == mode })?.id {
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label(L10n.text(group.id), systemImage: group.id == "guide.reset_section" ? "exclamationmark.triangle" : "keyboard")
                    }
                }
                Link(L10n.text("guide.manual"), destination: KeyboardGuideCatalog.manualURL)
                    .padding(.vertical, 8)
            }
            .pageColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func guideRow(_ entry: KeyboardGuideEntry) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                combination(entry).frame(width: 160, alignment: .leading)
                description(entry).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                combination(entry)
                description(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(entry))
    }

    private func combination(_ entry: KeyboardGuideEntry) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(entry.keys.enumerated()), id: \.offset) { index, key in
                if index > 0 { Text("+").foregroundStyle(.secondary) }
                KeyboardKeycap(label: key == "Knob" ? L10n.text("guide.knob") : key, isKnob: key == "Knob")
            }
        }
        .fixedSize()
    }

    private func description(_ entry: KeyboardGuideEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(actionTitle(entry))
                .fixedSize(horizontal: false, vertical: true)
            if entry.hold {
                Text(L10n.text("guide.hold"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionTitle(_ entry: KeyboardGuideEntry) -> String {
        entry.action.hasPrefix("guide.") ? L10n.text(entry.action) : entry.action
    }

    private func accessibilityText(_ entry: KeyboardGuideEntry) -> String {
        let keys = entry.keys.map { $0 == "Knob" ? L10n.text("guide.knob") : $0 }.joined(separator: " + ")
        return keys + ": " + actionTitle(entry) + (entry.hold ? ". " + L10n.text("guide.hold") : "")
    }
}
