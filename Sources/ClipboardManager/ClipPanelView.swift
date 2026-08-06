import SwiftUI
import ClipCore

/// Panel contents: a search field over a keyboard-navigable list of entries.
struct ClipPanelView: View {
    let entries: [ClipEntry]
    let onChoose: (ClipEntry) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selection = 0
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
        }
        // `onMoveCommand`/`onExitCommand` instead of `onKeyPress(.upArrow/.downArrow/.escape)`:
        // the search field is a real AppKit field editor (NSTextView) under the hood, and a
        // single-line field editor consumes Up/Down/Escape itself (cursor-to-start/end,
        // cancelOperation:) via `doCommandBySelector:` before SwiftUI's `onKeyPress` bubbling
        // — which only sees keys the SwiftUI focus system itself routes — ever gets a look.
        // `onMoveCommand`/`onExitCommand` hook into that same responder-chain command dispatch
        // (the mechanism `NSTextField` already forwards unhandled move/cancel commands through),
        // which is exactly how search-field-with-list-below navigation works natively on macOS
        // (e.g. Spotlight). Attaching them to the TextField itself wouldn't change this — the
        // problem is which command the field editor consumes, not which SwiftUI view holds the
        // modifier — so they stay on the outer VStack as in the brief's structure.
        .onMoveCommand { direction in
            switch direction {
            case .up: move(-1)
            case .down: move(1)
            default: break
            }
        }
        .onExitCommand(perform: onDismiss)
        .background(shortcutButtons)
    }

    /// ⌘1–⌘9 jump straight to a row. `keyboardShortcut` is a window-level key-equivalent
    /// (like a menu shortcut), resolved before ordinary key dispatch reaches the focused
    /// responder, so it fires regardless of what has focus — that part of the brief's
    /// approach is sound. What's uncertain is whether `.hidden()` keeps the button mounted
    /// for that resolution: `.hidden()` pulls a view out of the accessibility tree, and
    /// SwiftUI's key-equivalent registration has been reported (inconsistently, across
    /// versions) to skip hidden views. Zero-size + zero-opacity is the more conservative,
    /// widely-used idiom for "invisible but still interactive" — same visual result,
    /// without relying on `.hidden()`'s tree-removal semantics.
    private var shortcutButtons: some View {
        ZStack {
            ForEach(1...9, id: \.self) { n in
                Button("") { choose(index: n - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }
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
