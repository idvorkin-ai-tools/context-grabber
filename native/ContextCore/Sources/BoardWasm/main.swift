//  The board's rules for the Cockpit's web board, built by `just wasm` as a WASI reactor: the host calls `_initialize`,
//  then the exports in BoardWasm.swift (spec 2026-11-22-board-rules-on-the-web-design.md, The interface). A reactor runs
//  no main, so this file holds nothing on WASI; anywhere else the target is only this line.

#if !os(WASI)
  print("BoardWasm is the board's rules as WebAssembly: build it with `just wasm`.")
#endif
