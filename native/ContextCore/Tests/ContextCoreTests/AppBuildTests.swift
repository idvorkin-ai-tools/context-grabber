//  Story 1134 (bead context-grabber-esw3): every post the app sends the Cockpit says which build sent it.

import Foundation
import XCTest

@testable import ContextCore

final class AppBuildTests: XCTestCase {
  private let cockpit = "https://cockpit.example.ts.net:8443"
  private let build = AppBuild(build: "212", sha: "abc1234")

  private func body(_ request: URLRequest) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
  }

  private func assertStamped(_ request: URLRequest, file: StaticString = #filePath, line: UInt = #line) throws {
    let body = try body(request)
    XCTAssertEqual(body["app_build"] as? String, "212", file: file, line: line)
    XCTAssertEqual(body["app_sha"] as? String, "abc1234", file: file, line: line)
  }

  private func ask() throws -> ChatAsk {
    let json: [String: Any] = [
      "id": "igor2-88g.1620", "title": "Which?", "options": [["key": "a", "label": "Yes"]], "updated_at": "t1",
    ]
    return try JSONDecoder().decode(ChatAsk.self, from: JSONSerialization.data(withJSONObject: json))
  }

  func testTheBuildIsReadFromTheAppsStampedInfoPlist() {
    XCTAssertEqual(
      AppBuild(info: ["CFBundleVersion": "212", "GitSha": "abc1234", "CFBundleShortVersionString": "1.4"]), build)
    XCTAssertEqual(
      AppBuild(info: ["CFBundleVersion": "7", "GitSha": "dev"]).wire, ["app_build": "7", "app_sha": "dev"])
    // The test runner's bundle has a build number of its own but no stamp: it is not the app's.
    XCTAssertEqual(AppBuild(info: ["CFBundleVersion": "23.0"]), .none)
    XCTAssertEqual(AppBuild(info: [:]).wire, [:])
    XCTAssertEqual(AppBuild(info: ["GitSha": "abc1234"]).wire, ["app_sha": "abc1234"], "no build number: only the sha")
  }

  func testANewChatAndAReplyBothSayWhichBuildSentThem() throws {
    let first = InboxItem(id: "message-0001", kind: .link, sharedAt: 0, url: "https://example.com/a")
    try assertStamped(ChatSend.messageRequest(first, attachment: nil, cockpit: cockpit, build: build))
    let reply = InboxItem(id: "message-0002", kind: .text, sharedAt: 0, text: "and another", thread: "igor2-88g.1620")
    let request = try ChatSend.messageRequest(reply, attachment: "2026-11-22/a.jpg", cockpit: cockpit, build: build)
    try assertStamped(request)
    XCTAssertEqual(try body(request)["text"] as? String, "and another", "the message itself is unchanged")
  }

  func testABoardPictureKeepsItsBuildLineAndSaysTheSameTwoAsEveryPost() throws {
    var picture = WhiteboardPicture(board: "b1", title: "t", rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1)
    picture.build = "abc1234 main"
    let item = InboxItem(id: "p1", kind: .image, sharedAt: 0, thread: "t9", whiteboard: picture)
    let request = try ChatSend.messageRequest(item, attachment: "r", cockpit: cockpit, build: build)
    try assertStamped(request)
    XCTAssertEqual(try body(request)["build"] as? String, "abc1234 main", "the board debug page's line stays")
  }

  func testEveryDecisionVerbSaysWhichBuildSentIt() throws {
    let ask = try ask()
    let verbs: [ChatDecisions.Verb] = [
      .answer(ask.options[0]), .ownWords("later"), .snooze(.later), .close(reason: "done"), .abandon(reason: nil),
    ]
    for verb in verbs {
      try assertStamped(ChatDecisions.request(verb, ask: ask, cockpit: cockpit, build: build))
    }
  }

  func testABoardsEventsSayWhichBuildSentThem() throws {
    let report = BoardTurnReport(rev: 9, events: [])
    let request = try BoardEventsSend.request(
      board: "b1", report: report, cockpit: cockpit, build: "abc1234 main", appBuild: build)
    try assertStamped(request)
    XCTAssertEqual(try body(request)["build"] as? String, "abc1234 main")
  }

  func testABuildWithNoStampSendsNeitherName() throws {
    let item = InboxItem(id: "message-0003", kind: .text, sharedAt: 0, text: "hi")
    let message = try body(ChatSend.messageRequest(item, attachment: nil, cockpit: cockpit, build: .none))
    XCTAssertNil(message["app_build"])
    XCTAssertNil(message["app_sha"])
    let decision = try body(ChatDecisions.request(.snooze(.later), ask: ask(), cockpit: cockpit, build: .none))
    XCTAssertNil(decision["app_build"])
    XCTAssertNil(decision["app_sha"])
  }
}
