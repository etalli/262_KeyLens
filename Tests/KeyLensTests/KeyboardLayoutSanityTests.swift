import XCTest
import CoreGraphics
@testable import KeyLensCore

final class KeyboardLayoutSanityTests: XCTestCase {

    func testANSITableEntryCountIsStable() {
        // Guard against accidental deletions in the static keycode table.
        XCTAssertEqual(ANSILayout.table.count, 62)
    }

    func testStandardSplitMatchesHandTableSets() {
        let split = SplitKeyboardConfig.standardSplit
        let left = Set(ANSILayout.handTable.filter { $0.value == .left }.keys)
        let right = Set(ANSILayout.handTable.filter { $0.value == .right }.keys)

        XCTAssertEqual(split.leftKeys, left)
        XCTAssertEqual(split.rightKeys, right)
    }

    func testKeyCodeFallbackRejectsInvalidFormats() {
        let layout = ANSILayout()

        XCTAssertNil(layout.hand(for: "Key(x)"))
        XCTAssertNil(layout.hand(for: "Key(999)"))
        XCTAssertNil(layout.finger(for: "Key(x)"))
        XCTAssertNil(layout.finger(for: "Key(999)"))
    }

    func testRepresentativeKeyCodeFallbacksResolve() {
        let layout = ANSILayout()

        // Right Cmd
        XCTAssertEqual(layout.hand(for: "Key(54)"), .right)
        XCTAssertEqual(layout.finger(for: "Key(54)"), .thumb)

        // Right Shift
        XCTAssertEqual(layout.hand(for: "Key(60)"), .right)
        XCTAssertEqual(layout.finger(for: "Key(60)"), .pinky)
    }
}
