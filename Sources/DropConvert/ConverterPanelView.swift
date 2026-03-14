import SwiftUI
import UniformTypeIdentifiers

struct ConverterPanelView: View {
    let onDismiss: () -> Void

    @State private var droppedFile: URL?
    @State private var detectedType: FileType?
    @State private var selectedFormat: OutputFormat = .jpg
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var conversionResult: ConversionResult?

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.3)

                if let file = droppedFile, let type = detectedType {
                    conversionView(file: file, type: type)
                } else {
                    dropZone
                }
            }
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath.doc")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
            Text("DropConvert")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.blue : Color.primary.opacity(0.15),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.blue.opacity(0.07) : Color.clear)
                    )
                    .animation(.spring(response: 0.25), value: isTargeted)

                VStack(spacing: 10) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(isTargeted ? .blue : .secondary)
                        .animation(.spring(response: 0.25), value: isTargeted)

                    VStack(spacing: 4) {
                        Text("Drop a file to convert")
                            .font(.system(size: 13, weight: .medium))
                        Text("HEIC · MOV · PDF")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 28)
            }
            .padding(.horizontal, 16)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Conversion view

    private func conversionView(file: URL, type: FileType) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // File info row
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(type.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button { reset() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Format picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Convert to")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    ForEach(type.availableOutputFormats, id: \.self) { format in
                        FormatChip(format: format, isSelected: selectedFormat == format) {
                            selectedFormat = format
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            // Error message
            if case .failure(let error) = conversionResult {
                Text(error.localizedDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }

            // Convert button
            Button { convert(file: file) } label: {
                HStack(spacing: 6) {
                    if isConverting {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(.white)
                        Text("Converting…")
                    } else if case .success = conversionResult {
                        Image(systemName: "checkmark")
                        Text("Done!")
                    } else {
                        Text("Convert")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(conversionResultColor.gradient)
                )
            }
            .buttonStyle(.plain)
            .disabled(isConverting)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .animation(.spring(response: 0.3), value: isConverting)
        }
    }

    private var conversionResultColor: Color {
        if case .success = conversionResult { return .green }
        return .blue
    }

    // MARK: - Logic

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            DispatchQueue.main.async {
                droppedFile = url
                detectedType = FileType(url: url)
                if let type = detectedType {
                    selectedFormat = type.defaultOutputFormat
                }
            }
        }
        return true
    }

    private func convert(file: URL) {
        isConverting = true
        conversionResult = nil
        Task {
            do {
                let outputURL = try await ConversionEngine.convert(file: file, to: selectedFormat)
                await MainActor.run {
                    isConverting = false
                    conversionResult = .success(outputURL)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        NSWorkspace.shared.selectFile(
                            outputURL.path,
                            inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path
                        )
                        reset()
                    }
                }
            } catch {
                await MainActor.run {
                    isConverting = false
                    conversionResult = .failure(error)
                }
            }
        }
    }

    private func reset() {
        droppedFile = nil
        detectedType = nil
        conversionResult = nil
        isConverting = false
    }
}

// MARK: - Subviews

struct FormatChip: View {
    let format: OutputFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(format.label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.blue : Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
