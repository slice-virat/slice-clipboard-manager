import Foundation

@main
@MainActor
struct Runner {
    static func main() {
        runHistoryStoreTests()
        runHistoryInsertTests()
        runHistoryPromoteAndFilterTests()
        runConfigTests()
        Harness.finish()
    }
}
