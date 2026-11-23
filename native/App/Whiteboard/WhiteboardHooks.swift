//  The whiteboard's launch hook that does something at launch (docs/TESTING.md); `BoardFixtureHook` in ContextCore
//  reads it. What a board does by itself once open is `LaunchHooks.current.whiteboard`, read where it happens.

import ContextCore

extension AppModel {
  func runBoardFixtureHook(_ hook: BoardFixtureHook) {
    whiteboards.addFixture(hook.board, from: hook.from)
    if let thread = hook.thread { WhiteboardThreads().set(thread, board: hook.board) }
  }
}
