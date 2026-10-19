import Foundation
import XCTest

@testable import ContextCore

final class CallSettingsTests: XCTestCase {
  let now = Date(timeIntervalSince1970: 1000)
  let body = Data(
    #"{"ok":true,"schema":1,"extra":"ignored","voices":[{"pick":"igor","id":"server-clone","model":"eleven_v4_turbo"},{"pick":"tony","id":"stock","model":"eleven_flash_v2"}]}"#
      .utf8)

  func loaded() -> CallSettings {
    var settings = CallSettings()
    XCTAssertTrue(settings.receive(status: 200, data: body, etag: "v1", cacheControl: "private, max-age=300", at: now))
    return settings
  }

  func testRecommendationsReachTheWireWithTonyStillUsingTheDefaultVoice() throws {
    let settings = loaded()
    for voice in CallVoice.allCases {
      let fields = settings.fields(for: .eleven, voice: voice)
      let frame = CallProtocol.startFrame(backend: .eleven, voice: fields.voice, model: fields.model)
      let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(frame.utf8)) as? [String: Any])
      XCTAssertEqual(wire["voice"] as? String, voice == .tony ? "" : "server-clone")
      XCTAssertEqual(wire["model"] as? String, voice == .tony ? "eleven_flash_v2" : "eleven_v4_turbo")
      XCTAssertEqual(fields.source, "server")
    }
    XCTAssertEqual(settings.fields(for: .drill, voice: .igor).model, "eleven_v4_turbo")
    for backend in [CallBackend.gemini, .openai] {
      let fields = settings.fields(for: backend, voice: .igor)
      XCTAssertEqual(fields.voice, "")
      XCTAssertEqual(fields.model, "")
      XCTAssertEqual(fields.source, "bridge-default")
    }
  }

  func testRelaunchKeepsFreshnessAndValidatorAndExpiredCopyStillWorksOffline() {
    let settings = CallSettings(saved: loaded().saved)
    XCTAssertFalse(settings.needsRefresh(at: now.addingTimeInterval(299)))
    XCTAssertTrue(settings.needsRefresh(at: now.addingTimeInterval(300)))
    XCTAssertEqual(settings.etag, "v1")
    XCTAssertEqual(settings.fields(for: .eleven, voice: .igor).model, "eleven_v4_turbo")
    XCTAssertEqual(settings.fields(for: .eleven, voice: .igor).source, "cache")
  }

  func testNotModifiedRenewsFreshnessAndPersistsTheSameBody() {
    var settings = CallSettings(saved: loaded().saved)
    XCTAssertTrue(
      settings.receive(status: 304, data: Data(), etag: nil, cacheControl: nil, at: now.addingTimeInterval(300)))
    XCTAssertFalse(settings.needsRefresh(at: now.addingTimeInterval(599)))
    XCTAssertTrue(settings.needsRefresh(at: now.addingTimeInterval(600)))
    XCTAssertEqual(settings.etag, "v1")
    XCTAssertEqual(settings.fields(for: .eleven, voice: .igor).source, "server")
    XCTAssertEqual(CallSettings(saved: settings.saved).fields(for: .eleven, voice: .igor).model, "eleven_v4_turbo")
  }

  func testEveryInvalidResponseKeepsTheLastGoodCopyAndNeverPoisonsTheValidator() {
    let invalid: [(Int, Data)] = [
      (501, Data(#"{"ok":false,"error":"not ready"}"#.utf8)),
      (404, body), (500, body), (200, Data("not JSON".utf8)),
      (200, Data(#"{"ok":true,"schema":2,"voices":[]}"#.utf8)),
      (200, Data(#"{"ok":false,"schema":1,"voices":[]}"#.utf8)),
    ]
    for (status, data) in invalid {
      var settings = CallSettings(saved: loaded().saved)
      let saved = settings.saved
      XCTAssertFalse(settings.receive(status: status, data: data, etag: "bad", cacheControl: "max-age=999", at: now))
      XCTAssertEqual(json(settings.saved), json(saved))
      XCTAssertEqual(settings.fields(for: .eleven, voice: .igor).source, "cache")
      var empty = CallSettings()
      XCTAssertFalse(empty.receive(status: status, data: data, etag: "bad", cacheControl: nil, at: now))
      assertFallback(empty)
    }
  }

  func testNoCacheCorruptCacheAndNotModifiedWithoutABodyLeaveTheModelToTheBridge() {
    assertFallback(CallSettings())
    assertFallback(CallSettings(saved: "invalid"))
    var empty = CallSettings()
    XCTAssertFalse(empty.receive(status: 304, data: Data(), etag: "v1", cacheControl: nil, at: now))
    assertFallback(empty)
  }

  func testMissingPickAndUnusableRowsFallBackWithoutUsingTheDefaultModel() {
    for voices in [
      "[]", #"[{"pick":"someone-else","id":"other","model":"other"}]"#,
      #"[{"pick":"igor","id":"","model":"other"}]"#,
      #"[{"pick":"igor","id":"other","model":""}]"#,
    ] {
      var settings = CallSettings()
      let data = Data("{\"ok\":true,\"schema\":1,\"default_model\":\"ignored\",\"voices\":\(voices)}".utf8)
      XCTAssertTrue(settings.receive(status: 200, data: data, etag: nil, cacheControl: nil, at: now))
      assertFallback(settings)
    }
  }

  func testServerMaxAgeAndZeroAgeAreHonoured() {
    var settings = loaded()
    XCTAssertTrue(
      settings.receive(status: 304, data: Data(), etag: "v2", cacheControl: "private, max-age=\"10\"", at: now))
    XCTAssertFalse(settings.needsRefresh(at: now.addingTimeInterval(9)))
    XCTAssertTrue(settings.needsRefresh(at: now.addingTimeInterval(10)))
    XCTAssertTrue(settings.receive(status: 304, data: Data(), etag: nil, cacheControl: "max-age=0", at: now))
    XCTAssertTrue(settings.needsRefresh(at: now))
  }

  /// The persisted copy compared as JSON: JSONEncoder's key order differs between runs.
  private func json(_ saved: String?) -> NSDictionary? {
    saved.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? NSDictionary }
  }

  private func assertFallback(_ settings: CallSettings, file: StaticString = #filePath, line: UInt = #line) {
    let fields = settings.fields(for: .eleven, voice: .igor)
    XCTAssertEqual(fields.voice, "Nvd5I2HGnOWHNU0ijNEy", file: file, line: line)
    XCTAssertEqual(fields.model, "", file: file, line: line)
    XCTAssertEqual(fields.source, "bridge-default", file: file, line: line)
  }
}
