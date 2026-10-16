import SwiftUI
import UniformTypeIdentifiers

/// The keyboard's 128 × 128 display: an exact, animated preview of the chosen
/// image on the dark stage, plus clock sync and upload. Images can be dropped
/// straight onto the page.
struct ScreenView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTargeted = false
    @State private var isWindowVisible = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stage
                DeviceRequirementNote(.usbCable)
                controls
            }
            .pageColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(SidebarPage.screen.title)
        .trackingWindowVisibility($isWindowVisible)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.selectImage(at: url)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    // MARK: - Stage

    private var stage: some View {
        StageBackdrop {
            let frames = model.screenPreviewFrames
            let durations = frames.map(\.duration)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: frames.count < 2 || reduceMotion || !isWindowVisible)) { timeline in
                let index = ScreenPreviewPlayback.frameIndex(
                    durations: durations,
                    at: timeline.date.timeIntervalSinceReferenceDate
                )
                let current = frames.indices.contains(index) ? frames[index].image : nil

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 28) {
                        previewColumn(frames: frames, index: index, image: current)
                        keyboard(image: current)
                    }
                    VStack(spacing: 20) {
                        previewColumn(frames: frames, index: index, image: current)
                        keyboard(image: current)
                    }
                }
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                }
            }
        }
    }

    private func previewColumn(frames: [ScreenPreviewFrame], index: Int, image: CGImage?) -> some View {
        VStack(spacing: 12) {
            ScreenPreviewView(image: image)
                .overlay {
                    if model.isPreparingScreenPreview {
                        ProgressView()
                            .controlSize(.large)
                    }
                }
            if frames.count > 1 {
                ScreenFrameStrip(frames: frames, currentIndex: index)
            } else {
                Text(frames.isEmpty
                     ? L10n.text("Exactly what the keyboard screen will show")
                     : L10n.text("Still image"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func keyboard(image: CGImage?) -> some View {
        KeyboardStageView(
            settings: model.lastAppliedLighting ?? Self.idleLighting,
            screenImage: image
        )
        .frame(minWidth: 320, maxWidth: 520, maxHeight: 220)
    }

    private static let idleLighting = LightingSettings(
        mode: 7, brightness: 2, speed: 2, direction: 0, colorful: false, red: 255, green: 255, blue: 255
    )

    // MARK: - Controls

    private var controls: some View {
        ResponsiveColumns {
            pictureCard
            clockCard
        }
    }

    private var pictureCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                CardRow(title: L10n.text("Image")) {
                    HStack {
                        Text(model.selectedFile?.lastPathComponent ?? L10n.text("No file selected"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(model.selectedFile == nil ? .secondary : .primary)
                        Button(L10n.text("Choose File…")) {
                            model.chooseFile()
                        }
                        .disabled(model.isWorking)
                    }
                }
                Divider()
                CardRow(title: L10n.text("Fit")) {
                    Picker(L10n.text("Fit"), selection: $model.fitMode) {
                        ForEach(ScreenFitMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .disabled(model.isWorking)
                }
                Divider()
                CardRow(title: L10n.text("Slot")) {
                    Stepper("\(model.slot)", value: $model.slot, in: 1...255)
                        .disabled(isLocked)
                }
                if model.progress.totalChunks > 0 {
                    CardRow(title: L10n.text("Upload progress")) {
                        HStack {
                            ProgressView(value: model.progress.fraction)
                                .frame(maxWidth: 200)
                            Text(uploadProgressText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    CardFootnote(L10n.text("PNG, JPEG, GIF, BMP, TIFF or WebP. Shown at 128 × 128."))
                    Spacer()
                    Button {
                        model.uploadSelectedImage()
                    } label: {
                        Label(L10n.text("Upload to Keyboard"), systemImage: "display.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLocked || model.selectedFile == nil)
                }
                .padding(.top, 4)
            }
        } label: {
            Label(L10n.text("Picture"), systemImage: "photo")
        }
    }

    private var clockCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                CardRow(title: L10n.text("Keyboard clock"), detail: L10n.text("Sets the screen clock to this Mac's time.")) {
                    Button {
                        model.syncTime()
                    } label: {
                        Label(L10n.text("Sync Clock"), systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(isLocked)
                }
            }
        } label: {
            Label(L10n.text("Clock"), systemImage: "clock")
        }
    }

    /// True while another command runs or the cable is missing.
    private var isLocked: Bool {
        model.isWorking || !model.isWiredDevicePresent
    }

    private var uploadProgressText: String {
        guard model.progress.totalChunks > 0 else {
            return L10n.text("0%")
        }
        return L10n.format("%d%%  %d/%d", Int((model.progress.fraction * 100).rounded()), model.progress.sentChunks, model.progress.totalChunks)
    }
}
