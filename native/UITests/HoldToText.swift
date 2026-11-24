//  Stories 1309, 1310 (#1386): To text is only in the hold menu. A finger held still on the selected ink brings the menu
//  about the whole selection; its To text row reads it. And the selection's label is what says something is selected,
//  now nothing else shows beside it.

import XCTest

extension XCUIApplication {
  /// The label above a selection (story 1095): there while something is selected, gone with nothing selected.
  var selectionLabel: XCUIElement { descendants(matching: .any)["whiteboard-selection-label"] }

  /// A finger held still at `spot` (on the selected ink), then the hold menu's To text.
  func toTextFromHold(at spot: CGVector, file: StaticString = #filePath, line: UInt = #line) {
    coordinate(withNormalizedOffset: spot).press(forDuration: 1.0)
    let row = buttons["whiteboard-hold-to-text"]
    XCTAssertTrue(row.appears(within: 5), "the hold menu's To text: \(debugDescription)", file: file, line: line)
    row.tap()
  }
}
