import SwiftUI

/// Key response, sleep, and Game Mode. Game Mode lives here, next to the
/// settings it also sends (`setGameMode` sends the current response and sleep
/// values), so the user can see exactly what goes to the keyboard.
struct PerformanceView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DeviceRequirementNote(.receiver)
                ResponsiveColumns {
                    typingCard
                    gameModeCard
                }
            }
            .pageColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(SidebarPage.performance.title)
    }

    private var typingCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                CardRow(title: L10n.text("Key response")) {
                    Picker(L10n.text("Key response"), selection: $model.keyResponseLevel) {
                        ForEach(1...5, id: \.self) { value in
                            Text(WirelessAulaLabels.keyResponseTitle(value)).tag(value)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Divider()
                CardRow(title: L10n.text("Sleep after")) {
                    Picker(L10n.text("Sleep after"), selection: $model.sleepTime) {
                        ForEach(0...3, id: \.self) { value in
                            Text(WirelessAulaLabels.sleepTitle(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                HStack {
                    CardFootnote(L10n.text("Changes are sent when you press Apply."))
                    Spacer()
                    Button {
                        model.applyPerformance()
                    } label: {
                        Label(L10n.text("Apply"), systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(.top, 4)
            }
            .disabled(isLocked)
        } label: {
            Label(L10n.text("Typing"), systemImage: "keyboard")
        }
    }

    private var gameModeCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                CardFootnote(L10n.text("Locks the Command (⌘) key so it can't interrupt games. Also sends the Typing settings above."))
                HStack {
                    Button {
                        model.setGameMode(!model.gameModeEnabled)
                    } label: {
                        Label(
                            model.gameModeEnabled ? L10n.text("Disable Game Mode") : L10n.text("Enable Game Mode"),
                            systemImage: model.gameModeEnabled ? "lock.open" : "gamecontroller"
                        )
                    }
                    Button {
                        model.restoreCommandKey()
                    } label: {
                        Label(L10n.text("Restore Command Key"), systemImage: "command")
                    }
                    Spacer(minLength: 0)
                }
            }
            .disabled(isLocked)
        } label: {
            Label(L10n.text("Game Mode"), systemImage: "gamecontroller")
        }
    }

    private var isLocked: Bool {
        model.isWorking || !model.isDonglePresent
    }
}
