import AppKit
import SwiftUI
import ClipCore

/// Panel contents: a search field over a keyboard-navigable list of entries.
struct ClipPanelView: View {
    let entries: [ClipEntry]
    let onChoose: (ClipEntry) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @State private var keyMonitor: Any?
    @FocusState private var searchFocused: Bool

    private var visible: [ClipEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search clipboard history", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(12)
                .focused($searchFocused)
                .onSubmit(chooseSelected)
                .onChange(of: query) { _, _ in selection = 0 }

            Divider()

            if visible.isEmpty {
                Text(entries.isEmpty ? "Nothing copied yet" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(visible.enumerated()), id: \.element.id) { index, entry in
                                row(index: index, entry: entry)
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: selection) { _, new in
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 520, height: 400)
        .background(.regularMaterial)
        .onAppear {
            selection = 0
            query = ""
            searchFocused = true
            installKeyMonitor()
        }
        .onDisappear(perform: removeKeyMonitor)
    }

    // MARK: - Keyboard handling
    //
    // A local `NSEvent` monitor rather than SwiftUI's `onKeyPress`, `onMoveCommand`,
    // or hidden `keyboardShortcut` buttons. All three were tried and none receives
    // the arrow keys here: the search field is backed by a real AppKit field editor
    // (an `NSTextView`), and a single-line field editor consumes Up/Down/Escape
    // itself — moving the insertion point, or running `cancelOperation:` — without
    // forwarding them, so nothing upstream in the responder chain or the SwiftUI
    // focus system ever sees them.
    //
    // A local monitor runs ahead of that dispatch and only sees events already
    // destined for this app, so it needs no Accessibility permission — which
    // matters, because that permission is administrator-gated and unavailable on
    // some machines this ships to. Returning nil swallows the event so the field
    // editor never acts on it; returning the event passes it through untouched,
    // leaving ordinary typing alone.

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// The only modifiers whose presence should change what a key does here.
    ///
    /// Deliberately excludes `.function` and `.numericPad`: macOS sets BOTH on the
    /// arrow keys even when no modifier is held, so testing against
    /// `.deviceIndependentFlagsMask` makes an unmodified arrow press look modified
    /// and skip the keyCode switch entirely. `.capsLock` is excluded for the same
    /// reason — it should never change navigation.
    private static let relevantModifiers: NSEvent.ModifierFlags =
        [.command, .shift, .option, .control]

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(Self.relevantModifiers)

        // ⌘1–⌘9 jump straight to a row.
        if modifiers == .command,
           let characters = event.charactersIgnoringModifiers,
           let index = Int(characters), (1...9).contains(index) {
            choose(index: index - 1)
            return true
        }

        // Everything else is unmodified, so a shortcut like ⌘A in the search
        // field still behaves normally.
        guard modifiers.isEmpty else { return false }

        switch event.keyCode {
        case 126: move(-1); return true            // up arrow
        case 125: move(1); return true             // down arrow
        case 53:  onDismiss(); return true         // escape
        case 36, 76: chooseSelected(); return true // return, keypad enter
        default:  return false
        }
    }

    private func row(index: Int, entry: ClipEntry) -> some View {
        HStack(spacing: 10) {
            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            } else {
                Spacer().frame(width: 16)
            }
            Text(entry.preview)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(index == selection ? Color.accentColor.opacity(0.25) : .clear)
        .contentShape(Rectangle())
        .onTapGesture { choose(index: index) }
    }

    private func move(_ delta: Int) {
        guard !visible.isEmpty else { return }
        selection = (selection + delta + visible.count) % visible.count
    }

    private func chooseSelected() {
        choose(index: selection)
    }

    private func choose(index: Int) {
        guard visible.indices.contains(index) else { return }
        onChoose(visible[index])
    }
}
