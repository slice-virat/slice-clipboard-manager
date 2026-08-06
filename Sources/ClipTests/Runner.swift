import Foundation

@main
@MainActor
struct Runner {
    static func main() {
        runHistoryStoreTests()
        Harness.finish()
    }
}
