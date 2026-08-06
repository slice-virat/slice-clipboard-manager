import AppKit
import ClipCore

@main
@MainActor
struct AppMain {
    static func main() {
        let store = HistoryStore(maxEntries: 50)
        let monitor = ClipboardMonitor(filterSecrets: false) { text in
            store.insert(text)
            print("captured: \(ClipEntry(text: text).preview)")
            print("history: \(store.entries.map(\.preview))")
        }
        monitor.start()
        print("Monitoring clipboard — copy some text, then Ctrl-C.")
        RunLoop.main.run()
    }
}
