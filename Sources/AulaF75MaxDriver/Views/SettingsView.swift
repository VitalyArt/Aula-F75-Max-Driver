import SwiftUI

/// App preferences, plus the factory reset in its own card where it is hard
/// to hit by accident. `factoryReset()` shows its own confirmation alert.
struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            ResponsiveColumns {
                generalCard
                dangerCard
            }
            .pageColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(SidebarPage.settings.title)
    }

    private var generalCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                CardRow(title: L10n.text("Language")) {
                    Picker(L10n.text("Language"), selection: languageBinding) {
                        ForEach(model.sortedAvailableLanguages) { language in
                            Text("\(language.flag)  \(displayName(for: language))")
                                .tag(language.code)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Divider()
                CardRow(
                    title: L10n.text("Launch at Login"),
                    detail: L10n.text("Opens the app when you log in. Works without the keyboard connected.")
                ) {
                    Toggle(L10n.text("Launch at Login"), isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .disabled(model.isWorking)
        } label: {
            Label(L10n.text("General"), systemImage: "gearshape")
        }
    }

    private var dangerCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                DeviceRequirementNote(.usbCable)
                CardFootnote(L10n.text("Clears uploaded screen images and resets keyboard settings changed by this app."))
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        model.factoryReset()
                    } label: {
                        Label(L10n.text("Factory Reset Keyboard…"), systemImage: "trash")
                    }
                    .disabled(model.isWorking || !model.isWiredDevicePresent)
                }
            }
        } label: {
            Label(L10n.text("Danger Zone"), systemImage: "exclamationmark.triangle")
        }
    }

    /// The model stores the language and has its own setter, so the picker
    /// gets a custom binding: read the stored code, write through `setLanguage`.
    private var languageBinding: Binding<String> {
        Binding(
            get: { model.selectedLanguageCode },
            set: { model.setLanguage($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginEnabled },
            set: { _ in model.toggleLaunchAtLogin() }
        )
    }

    private func displayName(for language: AppViewModel.AppLanguage) -> String {
        language.code == "system" ? L10n.text(language.name) : language.name
    }
}
