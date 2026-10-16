import SwiftUI

/// RGB lighting on the dark keyboard stage. Every control updates the live
/// preview at once; nothing reaches the keyboard until Apply to Keyboard,
/// because the keyboard takes the whole lighting profile in one command.
struct LightingView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stage
                DeviceRequirementNote(.receiver)
                controls
                actionRow
                ProfilesPanel()
            }
            .pageColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(SidebarPage.lighting.title)
    }

    // MARK: - Stage

    private var stage: some View {
        StageBackdrop {
            VStack(spacing: 14) {
                HStack {
                    if model.hasUnappliedLighting {
                        Label(L10n.text("Preview · not applied"), systemImage: "eye")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.22), in: Capsule())
                            .foregroundStyle(.orange)
                            .transition(.opacity)
                    }
                    Spacer()
                    Text(L10n.text("Preview is an approximation of the keyboard's effect"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: model.hasUnappliedLighting)

                KeyboardStageView(settings: model.lightingSettings)
                    .frame(maxHeight: 380)

                effectStrip
            }
        }
    }

    /// All effects at once in a wrapping grid: no sideways scrolling, which
    /// a normal mouse wheel cannot do and which cut tiles off at the edges.
    private var effectStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 10)], spacing: 12) {
            ForEach(WirelessAulaLabels.rgbModes) { mode in
                EffectTile(
                    title: mode.title,
                    settings: preview(of: mode.id),
                    isSelected: model.rgbMode == mode.id
                ) {
                    model.rgbMode = mode.id
                }
            }
        }
    }

    /// The current settings with a different effect, for a tile's thumbnail.
    private func preview(of mode: Int) -> LightingSettings {
        var settings = model.lightingSettings
        settings.mode = mode
        settings.brightness = 5
        return settings
    }

    // MARK: - Controls

    private var controls: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                ControlCard(title: L10n.text("Brightness"), systemImage: "sun.max") {
                    numberPicker(selection: $model.rgbBrightness)
                }
                ControlCard(title: L10n.text("Speed"), systemImage: "gauge.with.dots.needle.33percent") {
                    numberPicker(selection: $model.rgbSpeed)
                }
            }
            GridRow {
                ControlCard(title: L10n.text("Direction"), systemImage: "arrow.left.and.right") {
                    Picker(L10n.text("Direction"), selection: $model.rgbDirection) {
                        ForEach(0...3, id: \.self) { value in
                            Text(WirelessAulaLabels.directionTitle(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                ControlCard(title: L10n.text("Colour"), systemImage: "paintpalette") {
                    HStack {
                        Picker(L10n.text("Colour"), selection: $model.rgbColorful) {
                            Text(L10n.text("Rainbow")).tag(true)
                            Text(L10n.text("Single colour")).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        ColorPicker(L10n.text("Pick a colour"), selection: $model.rgbColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(model.rgbColorful)
                            .opacity(model.rgbColorful ? 0.4 : 1)
                    }
                }
            }
        }
        // Previewing works without the receiver; only sending needs it.
        .disabled(model.isWorking)
    }

    private func numberPicker(selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(1...5, id: \.self) { value in
                Text("\(value)").tag(value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var actionRow: some View {
        HStack {
            Text(L10n.text("Changes are sent when you press Apply to Keyboard."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.text("Revert")) {
                if let applied = model.lastAppliedLighting {
                    model.loadLighting(applied)
                }
            }
            .disabled(model.lastAppliedLighting == nil || !model.hasUnappliedLighting || model.isWorking)

            Button {
                model.applyRGB()
            } label: {
                Label(L10n.text("Apply to Keyboard"), systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(model.isWorking || !model.isDonglePresent)
        }
    }
}

/// A titled card holding one group of lighting controls.
private struct ControlCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
    }
}

/// One effect in the horizontal strip: a colour thumbnail and its name.
private struct EffectTile: View {
    let title: String
    let settings: LightingSettings
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                EffectSwatch(settings: settings)
                    .frame(width: 86, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(width: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
