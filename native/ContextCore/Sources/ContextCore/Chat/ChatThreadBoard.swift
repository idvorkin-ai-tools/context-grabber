//
//  ChatThreadBoard.swift
//  #1091, stories 1122, 1123: the board a chat thread belongs to, for the thread's *Board* button. The newest message
//  sent from a board names it; failing that, a board of this device that started the thread.
//

import Foundation

public struct ChatThreadBoard: Equatable, Sendable {
  /// How the thread was known to be the board's: a message's `board`, or this device's board-to-thread record.
  public enum Source: String, Sendable {
    case message, device
  }

  public let board: String
  public let source: Source

  public init(board: String, source: Source) {
    self.board = board
    self.source = source
  }

  /// `deviceThreads` is this device's board id to thread key. Nil for a thread no board can be found for, or none yet.
  public static func find(thread: String?, messages: [ChatMessage], deviceThreads: [String: String]) -> ChatThreadBoard?
  {
    if let board = messages.last(where: { $0.board != nil })?.board {
      return ChatThreadBoard(board: board, source: .message)
    }
    guard let thread else { return nil }
    // Sorted, so two boards that once shared a thread always give the same one.
    let mine = deviceThreads.filter { $0.value == thread }.keys.sorted()
    return mine.first.map { ChatThreadBoard(board: $0, source: .device) }
  }
}
