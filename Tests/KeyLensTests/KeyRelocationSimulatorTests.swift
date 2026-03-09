import XCTest
@testable import KeyLensCore

final class KeyRelocationSimulatorTests: XCTestCase {
    
    private let layout = ANSILayout()

    func test_applySwap_bidirectionalMapping() {
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "a", key2: "b", to: &map)
        
        XCTAssertEqual(map["a"], "b")
        XCTAssertEqual(map["b"], "a")
    }
    
    func test_applySwap_chainsCorrectly() {
        // Swap A↔B, then B↔C.
        // A is now at B's original position.
        // B moves from A's position to C's position.
        // C moves to A's position.
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "a", key2: "b", to: &map)
        // map: a:b, b:a
        KeyRelocationSimulator.applySwap(key1: "b", key2: "c", to: &map)
        // b was at a. swapping b(at a) with c(at c).
        // c now at a. b now at c.
        
        XCTAssertEqual(map["a"], "b")
        XCTAssertEqual(map["b"], "c")
        XCTAssertEqual(map["c"], "a")
        
        let remapped = KeyRelocationSimulator.layout(applying: map, over: layout)
        XCTAssertEqual(remapped.position(for: "a"), layout.position(for: "b"))
        XCTAssertEqual(remapped.position(for: "b"), layout.position(for: "c"))
        XCTAssertEqual(remapped.position(for: "c"), layout.position(for: "a"))
    }
    
    func test_applySwap_identityRemoved() {
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "a", key2: "b", to: &map)
        XCTAssertEqual(map.count, 2)
        
        KeyRelocationSimulator.applySwap(key1: "a", key2: "b", to: &map)
        XCTAssertTrue(map.isEmpty, "Second swap should restore identity and empty the map")
    }

    func test_resolve_delegatesToPhysicalPosition() {
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
        let remapped = RemappedLayout(base: layout, relocationMap: map)
        
        // "f" should now use "j"'s finger (right index)
        XCTAssertEqual(remapped.finger(for: "f"), layout.finger(for: "j"))
        // "j" should now use "f"'s hand (left)
        XCTAssertEqual(remapped.hand(for: "j"), layout.hand(for: "f"))
    }
}
