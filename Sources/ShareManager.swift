import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
enum ShareManager {

    private static var previewWindow: NSWindow?

    /// Render the share card to an NSImage at @2x scale
    static func renderCard(data: ShareCardData) -> NSImage? {
        let view = ShareCardView(data: data)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(
                width: CGFloat(cgImage.width) / 2.0,
                height: CGFloat(cgImage.height) / 2.0
            )
        )
    }

    /// Show a preview window with the share card image and date navigation
    static func showPreview(state: AppState) {
        // Pre-render initial card so the window gets correct size
        let initialData = ShareCardData(from: state)
        guard let initialImage = renderCard(data: initialData) else { return }

        // Close existing preview if any
        previewWindow?.close()

        let previewView = SharePreviewView(state: state, initialImage: initialImage)
        let hostingView = NSHostingView(rootView: previewView)

        let hostingSize = hostingView.fittingSize
        let windowWidth = hostingSize.width
        let windowHeight = hostingSize.height

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        previewWindow = window
    }
}

// MARK: - Preview Window View

struct SharePreviewView: View {
    let state: AppState
    @State private var selectedDate: Date
    @State private var cardImage: NSImage
    @State private var currentDateString: String
    @State private var copied = false
    @State private var saved = false
    @State private var hoverCopy = false
    @State private var hoverSave = false
    @State private var hoverShare = false
    @State private var hoverPrev = false
    @State private var hoverNext = false

    private let accentGreen = Color(red: 0.20, green: 0.83, blue: 0.60)
    private let fmt = Database.dateFmt()

    init(state: AppState, initialImage: NSImage) {
        self.state = state
        _selectedDate = State(initialValue: Date())
        _cardImage = State(initialValue: initialImage)
        _currentDateString = State(initialValue: Database.todayString())
    }

    private var isToday: Bool {
        currentDateString == Database.todayString()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(nsColor: .windowBackgroundColor)

            VStack(spacing: 0) {
                // Header branding
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accentGreen)
                    Text("HealthTick")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                    Text("·")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.25))
                    Text(L.sharePreviewSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .padding(.top, 24)

                // Date navigator
                dateNavigator
                    .padding(.top, 12)

                // Card image — the hero
                Image(nsImage: cardImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
                    .padding(.horizontal, 48)
                    .padding(.top, 12)
                    .padding(.bottom, 56) // space for floating bar
            }

            // Floating action bar
            floatingBar
                .padding(.bottom, 16)
        }
        .frame(width: 440)
    }

    // MARK: - Date Navigator

    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
                currentDateString = fmt.string(from: selectedDate)
                renderForCurrentDate()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(hoverPrev ? 1.0 : 0.5))
                    .frame(width: 24, height: 24)
                    .background(
                        hoverPrev ? Color.primary.opacity(0.08) : Color.clear,
                        in: Circle()
                    )
            }
            .buttonStyle(.borderless)
            .handCursor()
            .onHover { hoverPrev = $0 }

            Text(formatNavigatorDate(currentDateString))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.7))
                .frame(minWidth: 120)

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
                currentDateString = fmt.string(from: selectedDate)
                renderForCurrentDate()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(isToday ? 0.15 : (hoverNext ? 1.0 : 0.5)))
                    .frame(width: 24, height: 24)
                    .background(
                        !isToday && hoverNext ? Color.primary.opacity(0.08) : Color.clear,
                        in: Circle()
                    )
            }
            .buttonStyle(.borderless)
            .handCursor()
            .onHover { hoverNext = $0 }
            .disabled(isToday)
        }
    }

    private func formatNavigatorDate(_ dateStr: String) -> String {
        if dateStr == Database.todayString() {
            return L.isZhAccess ? "今天" : "Today"
        }
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3 else { return dateStr }
        if L.isZhAccess {
            return "\(Int(parts[1]) ?? 0)月\(Int(parts[2]) ?? 0)日"
        }
        let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let m = Int(parts[1]) ?? 0
        return "\(months[m]) \(Int(parts[2]) ?? 0)"
    }

    // MARK: - Render

    private func renderForCurrentDate() {
        let data: ShareCardData
        if isToday {
            data = ShareCardData(from: state)
        } else {
            data = ShareCardData(forDate: currentDateString, goal: state.config.dailyGoal, state: state)
        }
        if let rendered = ShareManager.renderCard(data: data) {
            cardImage = rendered
        }
    }

    // MARK: - Floating Action Bar

    private var floatingBar: some View {
        HStack(spacing: 2) {
            floatingButton(
                icon: copied ? "checkmark" : "doc.on.doc",
                label: copied ? L.shareCopied : L.shareCopyAction,
                isActive: copied,
                isHover: hoverCopy
            ) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([cardImage])
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }
            .onHover { hoverCopy = $0 }

            floatingButton(
                icon: saved ? "checkmark" : "arrow.down.to.line",
                label: saved ? L.shareSaved : L.shareSaveAction,
                isActive: saved,
                isHover: hoverSave
            ) {
                saveImage()
            }
            .onHover { hoverSave = $0 }

            floatingButton(
                icon: "square.and.arrow.up",
                label: L.shareMore,
                isActive: false,
                isHover: hoverShare
            ) {
                let picker = NSSharingServicePicker(items: [cardImage])
                if let window = NSApp.keyWindow,
                   let contentView = window.contentView {
                    picker.show(
                        relativeTo: contentView.bounds,
                        of: contentView,
                        preferredEdge: .minY
                    )
                }
            }
            .onHover { hoverShare = $0 }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    private func floatingButton(icon: String, label: String, isActive: Bool, isHover: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isActive ? accentGreen : isHover ? .primary : .primary.opacity(0.65))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isHover ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.borderless)
        .handCursor()
        .animation(.easeOut(duration: 0.15), value: isHover)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    // MARK: - Save

    private func saveImage() {
        let image = cardImage
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "HealthTick-\(currentDateString).png"
        panel.level = .floating
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
            try? pngData.write(to: url)
            DispatchQueue.main.async {
                saved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
            }
        }
    }
}
