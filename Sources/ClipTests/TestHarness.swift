import Foundation

@MainActor
enum Harness {
    static var failures = 0
    static var total = 0

    static func expect(_ condition: Bool, _ name: String) {
        total += 1
        if condition {
            print("  ok   \(name)")
        } else {
            print("  FAIL \(name)")
            failures += 1
        }
    }

    static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
        total += 1
        if actual == expected {
            print("  ok   \(name)")
        } else {
            print("  FAIL \(name)\n         expected: \(expected)\n         actual:   \(actual)")
            failures += 1
        }
    }

    static func suite(_ name: String) {
        print("\n\(name)")
    }

    static func finish() -> Never {
        if failures == 0 {
            print("\nPASS — \(total) assertions")
            exit(0)
        } else {
            print("\nFAILED — \(failures) of \(total) assertions")
            exit(1)
        }
    }
}
