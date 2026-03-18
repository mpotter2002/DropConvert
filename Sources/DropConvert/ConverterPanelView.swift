import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement

struct ConverterPanelView: View {
    let onDismiss: () -> Void

    @State private var droppedFile: URL?
    @State private var detectedType: FileType?
    @State private var selectedFormat: OutputFormat = .jpg
    @State private var isTargeted = false
    @State private var isConverting = false
    @State private var conversionResult: ConversionResult?
    @State private var showingSettings = false

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
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(showingSettings ? .primary : .tertiary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                SettingsView()
            }
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

private enum UpdateState {
    case idle, checking, upToDate, available(version: String, downloadURL: URL), failed
}

struct VersionInfo: Decodable {
    let version: String
    let url: String
}

struct SettingsView: View {
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var updateState: UpdateState = .idle

    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let versionURL = URL(string: "https://dropconvert.app/version.json")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            Toggle("Open at Login", isOn: $launchAtLogin)
                .font(.system(size: 13))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }

            Divider()

            HStack(spacing: 8) {
                Button("Check for Updates") { checkForUpdates() }
                    .font(.system(size: 13))
                    .disabled({ if case .checking = updateState { return true }; return false }())

                Spacer()

                updateBadge
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if case .available(_, let url) = updateState {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Download Update")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.blue))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            Divider()

            Button("Quit DropConvert") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 13))
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Text("Version \(currentVersion)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .frame(width: 240)
    }

    @ViewBuilder
    private var updateBadge: some View {
        switch updateState {
        case .checking:
            ProgressView().scaleEffect(0.65)
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .available(let version, _):
            Text("v\(version) available")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
        case .failed:
            Text("Check failed")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .idle:
            EmptyView()
        }
    }

    private func checkForUpdates() {
        updateState = .checking
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: versionURL)
                let info = try JSONDecoder().decode(VersionInfo.self, from: data)
                await MainActor.run {
                    if isNewer(info.version, than: currentVersion), let url = URL(string: info.url) {
                        updateState = .available(version: info.version, downloadURL: url)
                    } else {
                        updateState = .upToDate
                    }
                }
            } catch {
                await MainActor.run { updateState = .failed }
            }
        }
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
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
