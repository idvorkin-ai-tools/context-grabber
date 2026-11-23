//  The review of a writing session, for the Cockpit's web board (spec 2026-11-23-board-interaction-review-design.md,
//  *The iPad and the web board, through one core*; story 1261): a record in the shared form, as JSONL, in; the report
//  out, as `BoardReview.Report` encodes it, so the web board's findings are the iPad's verdict for verdict. Stateless:
//  the loaded board is never touched, so a review can run beside a live board.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

enum WebReview {
  /// A record's JSONL reviewed: the report's JSON, or `{"error"}` saying why the record couldn't be read.
  static func review(_ jsonl: Data) -> Data {
    do {
      return BoardReview.run(try BoardSessionRecord(jsonl: jsonl)).json()
    } catch {
      let why = (error as? BoardSessionRecord.Unreadable)?.description ?? "\(error)"
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      return (try? encoder.encode(["error": "the record could not be read: \(why)"]))
        ?? Data(#"{"error":"no JSON"}"#.utf8)
    }
  }
}

#if os(WASI)
  /// A session's record (JSONL: its header, then one step per line) → a reply with its report as JSON (`checks`,
  /// `findings`, `to_look_at`), or `{"error"}`.
  @_expose(wasm, "bw_review")
  @_cdecl("bw_review")
  public func bwReview(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    reply(WebReview.review(input(pointer, length)))
  }
#endif
