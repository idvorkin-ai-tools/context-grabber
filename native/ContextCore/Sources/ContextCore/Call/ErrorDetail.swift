//  An error as log fields: its domain and code, the code as a FourCC when CoreAudio packed one into it
//  (2003329396 is 'what', the audio hardware's "unspecified"), and the same for the error underneath (#441).

import Foundation

public enum ErrorDetail {
  /// The four printable ASCII bytes a CoreAudio status packs into its code, or nil.
  public static func fourCC(_ code: Int) -> String? {
    guard code > 0, code <= Int(UInt32.max) else { return nil }
    let bytes = withUnsafeBytes(of: UInt32(code).bigEndian, Array.init)
    guard bytes.allSatisfy({ (0x20...0x7e).contains($0) }) else { return nil }
    return String(decoding: bytes, as: UTF8.self)
  }

  public static func fields(_ error: Error) -> [String: Any] {
    let e = error as NSError
    var out: [String: Any] = ["error_domain": e.domain, "error_code": e.code]
    if let cc = fourCC(e.code) { out["error_fourcc"] = cc }
    if let u = e.userInfo[NSUnderlyingErrorKey] as? NSError {
      out["underlying_domain"] = u.domain
      out["underlying_code"] = u.code
      if let cc = fourCC(u.code) { out["underlying_fourcc"] = cc }
    }
    return out
  }
}
