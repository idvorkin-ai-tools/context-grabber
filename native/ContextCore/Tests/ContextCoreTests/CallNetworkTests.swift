import XCTest

@testable import ContextCore

/// #440, #439, story 209: the network a call ran on, and the error a lost socket gave, as log fields.
final class CallNetworkTests: XCTestCase {
  func testAPathReadsAsItsStatusInterfacesAndCost() {
    let path = CallNetworkPath(
      status: "satisfied", interfaces: ["wifi", "other"], expensive: false, constrained: false)
    let f = path.fields
    XCTAssertEqual(f["status"] as? String, "satisfied")
    XCTAssertEqual(f["interfaces"] as? String, "wifi+other")
    XCTAssertEqual(f["expensive"] as? Bool, false)
    XCTAssertEqual(f["constrained"] as? Bool, false)
  }

  func testAPathWithNoInterfaceSaysNone() {
    let path = CallNetworkPath(status: "unsatisfied", interfaces: [], expensive: false, constrained: false)
    XCTAssertEqual(path.fields["interfaces"] as? String, "none")
  }

  func testTheTypesInUseAreKeptApartFromTheAvailableOnes() {
    // Codex on #521: with Wi-Fi and cellular both up, the call's traffic is on one of them.
    let path = CallNetworkPath(
      status: "satisfied", interfaces: ["wifi"], available: ["wifi", "cellular", "other"], expensive: false,
      constrained: false)
    XCTAssertEqual(path.fields["interfaces"] as? String, "wifi")
    XCTAssertEqual(path.fields["available"] as? String, "wifi+cellular+other")
    XCTAssertNotEqual(
      path, CallNetworkPath(status: "satisfied", interfaces: ["wifi"], expensive: false, constrained: false))
  }

  func testAMoveFromWifiToCellularIsAChange() {
    let wifi = CallNetworkPath(status: "satisfied", interfaces: ["wifi"], expensive: false, constrained: false)
    let cell = CallNetworkPath(status: "satisfied", interfaces: ["cellular"], expensive: true, constrained: false)
    XCTAssertNotEqual(wifi, cell)
  }

  func testALostSocketNamesTheCodeTheUnderlyingErrorAndTheStreamError() {
    let underlying = NSError(
      domain: "kCFErrorDomainCFNetwork", code: -1005,
      userInfo: ["_kCFStreamErrorDomainKey": 1, "_kCFStreamErrorCodeKey": 57])
    let error = NSError(
      domain: NSURLErrorDomain, code: -1005,
      userInfo: [
        NSLocalizedDescriptionKey: "The network connection was lost.", NSUnderlyingErrorKey: underlying,
        "_kCFStreamErrorDomainKey": 1, "_kCFStreamErrorCodeKey": 57,
      ])
    XCTAssertEqual(
      SocketErrorDetail.describe(error),
      "The network connection was lost. (NSURLErrorDomain -1005; under kCFErrorDomainCFNetwork -1005; stream 1/57)")
  }

  func testAPlainErrorIsJustItsSentenceAndCode() {
    let error = NSError(domain: NSURLErrorDomain, code: -1001, userInfo: [NSLocalizedDescriptionKey: "timed out"])
    XCTAssertEqual(SocketErrorDetail.describe(error), "timed out (NSURLErrorDomain -1001)")
  }
}
