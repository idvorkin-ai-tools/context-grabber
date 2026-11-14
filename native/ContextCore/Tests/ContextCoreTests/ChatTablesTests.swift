//  Story 747 (#817): a Markdown table in a message is a grid; everything else stays as written.

import XCTest

@testable import ContextCore

final class ChatTablesTests: XCTestCase {
  private typealias T = ChatTables

  /// Story 747's message: words, the laptop comparison, words.
  func testTheLaptopComparison() {
    let message = """
      Here's how they compare:
      | | Weight | Battery | Price |
      |---|:---:|---:|---|
      | Air | 1.2 kg | 18 h | $1,099 |
      | Pro 14 | 1.6 kg | 22 h | $1,999 |
      | XPS | 1.4 kg | 12 h | $1,299 |
      Want the cheapest?
      """
    XCTAssertEqual(
      T.blocks(in: message),
      [
        .text("Here's how they compare:"),
        .table(
          T.Table(
            heading: ["", "Weight", "Battery", "Price"], alignments: [.leading, .center, .trailing, .leading],
            rows: [
              ["Air", "1.2 kg", "18 h", "$1,099"], ["Pro 14", "1.6 kg", "22 h", "$1,999"],
              ["XPS", "1.4 kg", "12 h", "$1,299"],
            ])),
        .text("Want the cheapest?"),
      ])
  }

  /// Story 747: VoiceOver reads the grid row by row, each cell after its heading, and no pipes or dashes. Was
  /// `ChatTableUITests`' reading of the bubble's label (story 770).
  func testTheTableReadsRowByRow() throws {
    let message = """
      | | Weight | Battery | Price |
      |---|:---:|---:|---|
      | Air | 1.2 kg | 18 h | $1,099 |
      | Pro 14 | 1.6 kg | 22 h | $1,999 |
      | XPS | 1.4 kg | 12 h | $1,299 |
      """
    guard case .table(let table) = try XCTUnwrap(T.blocks(in: message).first) else { return XCTFail("no table") }
    XCTAssertEqual(
      table.spoken,
      "Air, Weight 1.2 kg, Battery 18 h, Price $1,099; Pro 14, Weight 1.6 kg, Battery 22 h, Price $1,999; "
        + "XPS, Weight 1.4 kg, Battery 12 h, Price $1,299")
    XCTAssertFalse(table.spoken.contains("|"))
    XCTAssertFalse(table.spoken.contains("---"))
    guard case .table(let heading) = try XCTUnwrap(T.blocks(in: "| A | | B |\n|---|---|---|").first) else {
      return XCTFail("no table")
    }
    XCTAssertEqual(heading.spoken, "A, B", "a heading alone reads its cells")
  }

  func testAMessageWithNoTableIsOneText() {
    let message = "Plain words\n\nwith a blank line and a | pipe"
    XCTAssertEqual(T.blocks(in: message), [.text(message)])
  }

  func testPipesWithNoDashesRowStayAsWritten() {
    let message = "| a | b |\n| c | d |"
    XCTAssertEqual(T.blocks(in: message), [.text(message)])
  }

  func testADashesRowOfAnotherWidthIsNotATable() {
    let message = "| a | b |\n|---|---|---|"
    XCTAssertEqual(T.blocks(in: message), [.text(message)])
  }

  func testARuleUnderALineWithAPipeIsNotATable() {
    let message = "this | that\n---"
    XCTAssertEqual(T.blocks(in: message), [.text(message)])
  }

  func testOuterPipesAreOptional() {
    XCTAssertEqual(
      T.blocks(in: "a | b\n--- | ---\n1 | 2"),
      [.table(T.Table(heading: ["a", "b"], alignments: [.leading, .leading], rows: [["1", "2"]]))])
  }

  func testAShortRowIsFilledAndALongOneCut() {
    XCTAssertEqual(
      T.blocks(in: "| a | b | c |\n|---|---|---|\n| 1 |\n| 1 | 2 | 3 | 4 |"),
      [
        .table(
          T.Table(
            heading: ["a", "b", "c"], alignments: [.leading, .leading, .leading],
            rows: [["1", "", ""], ["1", "2", "3"]]))
      ])
  }

  func testAnEscapedPipeStaysInItsCell() {
    XCTAssertEqual(
      T.blocks(in: "| cmd | what |\n|---|---|\n| `a \\| b` | pipe |"),
      [.table(T.Table(heading: ["cmd", "what"], alignments: [.leading, .leading], rows: [["`a | b`", "pipe"]]))])
  }

  func testAHeadingAloneIsATableWithNoRows() {
    XCTAssertEqual(
      T.blocks(in: "| a | b |\n|---|---|\nafter"),
      [.table(T.Table(heading: ["a", "b"], alignments: [.leading, .leading], rows: [])), .text("after")])
  }

  func testTwoTablesWithWordsBetween() {
    let blocks = T.blocks(in: "| a |\n|---|\n| 1 |\n\nand\n| b |\n|:-:|\n| 2 |")
    XCTAssertEqual(blocks.count, 3)
    XCTAssertEqual(blocks[1], .text("\nand"))
    XCTAssertEqual(blocks[2], .table(T.Table(heading: ["b"], alignments: [.center], rows: [["2"]])))
  }
}
