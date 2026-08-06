import AppKit
import ClipCore

/// Temporary Task 7 verification harness for `HotkeyManager`.
///
/// This cannot exercise the hotkey interactively (no synthetic keystroke
/// without Accessibility permission, and no human at the keyboard here), so
/// it verifies the parts of Carbon registration that are observable
/// programmatically:
///   1. `register()` succeeds for the default binding.
///   2. Registering the *same* combination again while it is still held is
///      rejected by the OS (proves the binding is real and system-wide).
///   3. `unregister()` releases the binding, so registering it again succeeds.
@main
@MainActor
struct AppMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        var failures = 0

        // Check 1: registration succeeds.
        let first = HotkeyManager(config: .default) { }
        do {
            try first.register()
            print("PASS: check 1 - register() succeeded for the default binding")
        } catch {
            print("FAIL: check 1 - register() threw: \(error.localizedDescription)")
            failures += 1
        }

        // Check 2: registering the same combination again, while the first
        // registration is still held, must be rejected by Carbon.
        let second = HotkeyManager(config: .default) { }
        do {
            try second.register()
            print("FAIL: check 2 - duplicate register() unexpectedly succeeded (binding was not exclusive)")
            failures += 1
            second.unregister()
        } catch HotkeyManager.RegistrationError.registrationFailed(let status) {
            if status == -9878 {
                print("PASS: check 2 - duplicate register() threw registrationFailed(-9878), i.e. eventHotKeyExistsErr")
            } else {
                print("PASS: check 2 - duplicate register() threw registrationFailed(\(status)) (expected -9878/eventHotKeyExistsErr; OS returned a different status)")
            }
        } catch {
            print("FAIL: check 2 - duplicate register() threw an unexpected error: \(error)")
            failures += 1
        }

        // Check 3: unregister() releases the binding, so re-registering the
        // same combination now succeeds.
        first.unregister()
        let third = HotkeyManager(config: .default) { }
        do {
            try third.register()
            print("PASS: check 3 - register() succeeded again after unregister()")
            third.unregister()
        } catch {
            print("FAIL: check 3 - register() after unregister() threw: \(error.localizedDescription)")
            failures += 1
        }

        if failures == 0 {
            print("All checks passed.")
        } else {
            print("\(failures) check(s) failed.")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
