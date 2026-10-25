import XCTest

@testable import ContextCore

/// #441, story 208: a failed audio start says which error it was, not only the system's sentence.
final class ErrorDetailTests: XCTestCase {
  func testTheAudioHardwaresUnspecifiedErrorReadsAsItsFourCC() {
    XCTAssertEqual(ErrorDetail.fourCC(2_003_329_396), "what")
  }

  func testAnOrdinaryCodeHasNoFourCC() {
    XCTAssertNil(ErrorDetail.fourCC(-1005))
    XCTAssertNil(ErrorDetail.fourCC(0))
    XCTAssertNil(ErrorDetail.fourCC(-50))
  }

  func testFieldsCarryTheDomainTheCodeAndTheUnderlyingError() {
    let underlying = NSError(domain: NSOSStatusErrorDomain, code: 561_017_449)  // '!pri'
    let error = NSError(
      domain: "com.apple.coreaudio.avfaudio", code: 2_003_329_396, userInfo: [NSUnderlyingErrorKey: underlying])
    let f = ErrorDetail.fields(error)
    XCTAssertEqual(f["error_domain"] as? String, "com.apple.coreaudio.avfaudio")
    XCTAssertEqual(f["error_code"] as? Int, 2_003_329_396)
    XCTAssertEqual(f["error_fourcc"] as? String, "what")
    XCTAssertEqual(f["underlying_domain"] as? String, NSOSStatusErrorDomain)
    XCTAssertEqual(f["underlying_code"] as? Int, 561_017_449)
    XCTAssertEqual(f["underlying_fourcc"] as? String, "!pri")
  }

  func testAnErrorWithNothingUnderneathHasNoUnderlyingFields() {
    let f = ErrorDetail.fields(NSError(domain: NSURLErrorDomain, code: -1005))
    XCTAssertEqual(f["error_code"] as? Int, -1005)
    XCTAssertNil(f["error_fourcc"])
    XCTAssertNil(f["underlying_domain"])
  }
}
