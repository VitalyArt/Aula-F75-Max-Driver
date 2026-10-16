import SwiftUI

/// What happens when the user picks a saved profile. Shared by the Lighting
/// page and the Home switcher so both behave the same way.
@MainActor
enum ProfileActions {
    /// True when the controls hold edits that are neither applied nor saved —
    /// switching profile now would throw them away.
    static func hasUnsavedEdits(model: AppViewModel, store: LightingProfileStore) -> Bool {
        let current = model.lightingSettings
        let matchesApplied = current == model.lastAppliedLighting
        let matchesProfile = current == store.selectedProfile?.settings
        let isUntouchedDefault = model.lastAppliedLighting == nil
            && store.selectedProfile == nil
            && current == model.launchLighting
        return !matchesApplied && !matchesProfile && !isUntouchedDefault
    }

    /// Loads the profile into the controls and sends it to the keyboard when
    /// that is possible right now. Without the receiver (or while another
    /// command runs) it only changes the preview.
    static func select(_ profile: LightingProfile, model: AppViewModel, store: LightingProfileStore) {
        model.loadLighting(profile.settings)
        store.selectedID = profile.id
        if model.isDonglePresent && !model.isWorking {
            model.applyRGB()
        }
    }
}

/// Saved lighting looks: pick one to switch, or save, update, rename and
/// delete them. Profiles are stored on this Mac.
struct ProfilesPanel: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var store: LightingProfileStore

    @State private var nameSheet: NameSheetMode?
    @State private var pendingProfile: LightingProfile?
    @State private var profileToDelete: LightingProfile?

    private enum NameSheetMode: Identifiable {
        case saveNew
        case rename(LightingProfile)

        var id: String {
            switch self {
            case .saveNew: return "new"
            case .rename(let profile): return profile.id.uuidString
            }
        }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if store.profiles.isEmpty {
                    Text(L10n.text("No saved profiles yet. Set up a look you like and save it."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(store.profiles) { profile in
                            ProfileChip(
                                profile: profile,
                                isSelected: profile.id == store.selectedID,
                                select: { requestSelect(profile) }
                            )
                            .contextMenu {
                                Button(L10n.text("Rename…")) { nameSheet = .rename(profile) }
                                Button(L10n.text("Delete…"), role: .destructive) { profileToDelete = profile }
                            }
                        }
                    }
                }

                HStack {
                    Button {
                        nameSheet = .saveNew
                    } label: {
                        Label(L10n.text("Save as New Profile…"), systemImage: "plus")
                    }
                    .keyboardShortcut("s", modifiers: .command)

                    if let selected = store.selectedProfile {
                        Button(L10n.text("Update")) {
                            store.update(selected.id, settings: model.lightingSettings)
                        }
                        .disabled(selected.settings == model.lightingSettings)
                        .help(L10n.text("Save the current settings into the selected profile"))

                        Button(L10n.text("Rename…")) { nameSheet = .rename(selected) }
                        Button(L10n.text("Delete…"), role: .destructive) { profileToDelete = selected }
                    }
                    Spacer()
                }
                .controlSize(.small)
            }
            .padding(4)
        } label: {
            Label(L10n.text("Profiles"), systemImage: "square.stack.3d.up")
        }
        .sheet(item: $nameSheet) { mode in
            switch mode {
            case .saveNew:
                ProfileNameSheet(title: L10n.text("Save as New Profile"), initialName: "") { name in
                    let profile = store.add(name: name, settings: model.lightingSettings)
                    store.selectedID = profile.id
                }
            case .rename(let profile):
                ProfileNameSheet(title: L10n.text("Rename Profile"), initialName: profile.name) { name in
                    store.rename(profile.id, to: name)
                }
            }
        }
        .confirmationDialog(
            L10n.text("Discard your unsaved lighting changes?"),
            isPresented: Binding(get: { pendingProfile != nil }, set: { if !$0 { pendingProfile = nil } }),
            presenting: pendingProfile
        ) { profile in
            Button(L10n.text("Discard and Switch"), role: .destructive) {
                ProfileActions.select(profile, model: model, store: store)
            }
            Button(L10n.text("Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            L10n.text("Delete this profile?"),
            isPresented: Binding(get: { profileToDelete != nil }, set: { if !$0 { profileToDelete = nil } }),
            presenting: profileToDelete
        ) { profile in
            Button(L10n.text("Delete"), role: .destructive) {
                store.delete(profile.id)
            }
            Button(L10n.text("Cancel"), role: .cancel) {}
        } message: { profile in
            Text(profile.name)
        }
    }

    private func requestSelect(_ profile: LightingProfile) {
        if ProfileActions.hasUnsavedEdits(model: model, store: store) {
            pendingProfile = profile
        } else {
            ProfileActions.select(profile, model: model, store: store)
        }
    }
}

/// One saved profile as a clickable chip with a small colour preview.
struct ProfileChip: View {
    let profile: LightingProfile
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                EffectSwatch(settings: profile.settings)
                    .frame(width: 34, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text(profile.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A still strip of colours showing roughly what an effect looks like, drawn
/// from the same renderer as the keyboard preview.
struct EffectSwatch: View {
    let settings: LightingSettings

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.06)))
            let columns = 12
            let width = size.width / CGFloat(columns)
            for column in 0..<columns {
                let x = (Double(column) + 0.5) / Double(columns)
                // A few rows averaged so sparse effects still show colour.
                var red = 0.0, green = 0.0, blue = 0.0
                for row in 0..<3 {
                    let rgb = LightingEffectRenderer.color(for: settings, at: CGPoint(x: x, y: 0.25 + Double(row) * 0.25), time: 1.7)
                    red = max(red, rgb.r)
                    green = max(green, rgb.g)
                    blue = max(blue, rgb.b)
                }
                let rect = CGRect(x: CGFloat(column) * width, y: 0, width: width + 0.5, height: size.height)
                context.fill(Path(rect), with: .color(Color(.sRGB, red: red, green: green, blue: blue)))
            }
        }
    }
}

/// Asks for a profile name. Save is disabled until the name has text.
private struct ProfileNameSheet: View {
    let title: String
    let initialName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            TextField(L10n.text("Profile name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit(save)
            HStack {
                Spacer()
                Button(L10n.text("Cancel"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.text("Save"), action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .onAppear { name = initialName }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName)
        dismiss()
    }
}

/// A compact row of saved profiles for the Home page: one click switches the
/// keyboard's lighting, with the same unsaved-edits check as the Lighting page.
struct ProfileSwitcherRow: View {
    @EnvironmentObject private var model: AppViewModel
    @EnvironmentObject private var store: LightingProfileStore
    @State private var pendingProfile: LightingProfile?

    var body: some View {
        if !store.profiles.isEmpty {
            GroupBox {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                        ForEach(store.profiles) { profile in
                            ProfileChip(profile: profile, isSelected: profile.id == store.selectedID) {
                                if ProfileActions.hasUnsavedEdits(model: model, store: store) {
                                    pendingProfile = profile
                                } else {
                                    ProfileActions.select(profile, model: model, store: store)
                                }
                            }
                        }
                }
            } label: {
                Label(L10n.text("Lighting Profiles"), systemImage: "square.stack.3d.up")
            }
            .confirmationDialog(
                L10n.text("Discard your unsaved lighting changes?"),
                isPresented: Binding(get: { pendingProfile != nil }, set: { if !$0 { pendingProfile = nil } }),
                presenting: pendingProfile
            ) { profile in
                Button(L10n.text("Discard and Switch"), role: .destructive) {
                    ProfileActions.select(profile, model: model, store: store)
                }
                Button(L10n.text("Cancel"), role: .cancel) {}
            }
        }
    }
}
