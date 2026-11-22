# Whiteboard: one edit lane for the board's markup sets (arch 2)

Bead: context-grabber-546e. Source: the whiteboard architecture review of 2026-11-21 (recommendation 2).

No behaviour change. Nothing in a spec or a story moves, because the board does the same things in the same order.

## Why

The canvas controller set `paper.markup` at 12 places. Each one wrapped the set in its own `quiet = true … quiet = false`
and registered its own undo step beside it. Only 5 of them read back what PaperKit held afterwards. Six of the last 11
fixes in the two big whiteboard files were in this commit-and-undo path. A new gesture had to assemble the same steps by
hand, and the history shows they were easy to get wrong.

## PR 1: the move (this PR)

- `PaperBoard+EditLane.swift` holds the lane:
  - `setMarkup(_:stepBack:named:)` registers the undo step first when given one, then sets the markup with the
    change callback quiet. It returns a `PaperMarkupSet`.
  - `PaperMarkupSet` holds `asked` and a lazy `held` (`paper.markup ?? asked`), read only when a caller asks.
  - `quietly(_:)` is the quiet bracket for work that is not a set. It is used only by the drop's take-back of PaperKit's
    step.
- All 12 sites call `setMarkup`. `rg "paper\.markup = "` and `rg "quiet = "` now find only the lane.
- Eight `registerStepBack` calls fold into the set they preceded: scratch-out, delete paste, replace ink, keep, put,
  move, and both branches of `step(to:)`. In each, only value mutations of the local markup sat between the register
  and the set, so the order on the undo manager is unchanged.
- These stay as they were:
  - The drop registers its Move step before `put(…, stepBack: false)`, and it stays registered even when the put fails.
  - The 4 `takeBackPaperKitsStep` calls are unchanged, including #966's probe. Only the drop's call is quiet, as before.
  - `quietly` sets the flag on and then off, and never restores it. A step back inside it that sets the markup still
    leaves the flag off, as it always did.
- Read-back is unchanged. The 5 sites that read what PaperKit holds read `landed.held` (load, delete paste, replace
  ink, keep, put) at the same point as before. The other 7 still use what they asked for and add no new read.
- `quiet` and `registerStepBack` lose `private` so the lane's file can reach them. Only the lane sets `quiet`.

## Later PRs, one call site at a time

1. **A typed outcome.** `setMarkup` returns held or refused, by comparing the frames PaperKit holds with the frames
   asked for (#999, #1015). It logs one `paper_set` event that names the site. #1065's `BoardCanvasOutcome` is a
   ContextCore type and cannot carry `PaperMarkup`, so `applyOps` maps the lane's outcome onto it, a refused set
   becoming `.failed`.
2. **Read-back at the 7 sites that don't read today.** Grow, scratch-out, margin hold, pick-up, move and both `step`
   branches each switch from what they asked for to what is held, each with its own rung-2 check. Four of these run
   inside PaperKit's change callback or inside an undo.
3. **The follow-up steps** (frames, the model's verb, `noteInk`, lines, page number, redraw). These move into the lane
   behind a reason enum, and `takeBackPaperKitsStep` joins it. #966's behaviour is kept, and the UI tests for keep,
   scratch, paste and undo are run at each step.

## Verification

- Rung 0/1: `just native-test`.
- Rung 1.5: `just native-build-mac`.
- App/Whiteboard has no host tests, so these rungs show that the move compiles, not how undo behaves. The rung-2
  whiteboard UI tests cover undo.
