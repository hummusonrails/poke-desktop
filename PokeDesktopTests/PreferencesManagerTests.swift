import XCTest
@testable import PokeDesktop

final class PreferencesManagerTests: XCTestCase {
    var prefs: PreferencesManager!

    override func setUp() {
        prefs = PreferencesManager(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    func testDefaultValues() {
        XCTAssertNil(prefs.pokeHandleId)
        XCTAssertEqual(prefs.lastSeenRowId, 0)
        XCTAssertTrue(prefs.readAloudEnabled)
        XCTAssertTrue(prefs.autoLaunchEnabled)
    }

    func testPersistence() {
        prefs.pokeHandleId = 7
        prefs.lastSeenRowId = 999
        prefs.readAloudEnabled = false
        XCTAssertEqual(prefs.pokeHandleId, 7)
        XCTAssertEqual(prefs.lastSeenRowId, 999)
        XCTAssertFalse(prefs.readAloudEnabled)
    }
}
