# Story ID reservations and the pre-merge check

Bead `context-grabber-jg3w`. Stories 791 to 794 in [Building and testing](../../stories/11-building-and-testing.md).

## Summary

Many agents add user stories at once, each on its own branch. Each took "the next free ID" by reading its own
branch, so each PR passed the story ID check alone, and once two of them merged, main held the same ID twice. That
happened four times on 2026-11-22 (955, 1101, 1155, 1113–1115). The check (story 789) can only see one tree; nothing
saw the other branches.

Two things close the gap: a new story's ID is *reserved* rather than picked, and the check is run once more on the
branch as it would merge, right before merging.

## Goals

- Two agents on this Mac asking for an ID at the same moment never get the same one.
- An ID another open PR already added, or that main already has, is never handed out, even when that PR came from
  another machine.
- A collision that slips through (two branches that merged in between) is caught before the second merge, not on
  main.

## Non-goals

- A server or a shared ledger across machines. Open PRs are the cross-machine record; a reservation made on another
  machine and not yet pushed is not seen.
- Making the merge atomic: a PR that merges in the seconds between the pre-merge check and the merge can still
  collide. The host rung on main and the next pre-merge catch it.
- Renumbering stories that already collide on main.

## Reserving an ID

The story ID tool gets a reserve command that takes a journey (any of its story files, or a word from its row in the
journey table, like `building` or `whiteboard`) and how many IDs are wanted (one by default). It prints the IDs, one
per line and nothing else, lowest first, from that journey's IDs column.

An ID is not handed out when it is:

- a story on main as it is on the remote now (fetched first, not the checkout's possibly stale copy),
- a story in the tree it runs in (the branch's own new stories),
- a story heading added by any open PR,
- reserved on this Mac in the last 24 hours and not yet on main.

Reservations are kept in a small ledger on this Mac, outside the repository, read and written under a lock so two
reservations at once are taken one after the other. Each records the ID, its journey, the branch and when. A
reservation lapses after 24 hours, or as soon as its ID is on main (the story merged), whichever is first.

It fails, and hands out nothing, when it can't fetch main or list the open PRs (an ID chosen without them is the bug
this fixes), when the journey names no row or more than one, and when the journey's IDs column has no free ID left
(see below).

When a journey has too few free IDs, the message names the journey as its row does (its name, not only its first
file), its IDs column, and how to extend it: add an unused block to the end of its row's IDs column in the journey
table, the next block above every ID any journey holds (it says which, a hundred wide), then reserve again. It also
lists how many free IDs every journey has left, so a second journey running low is seen at the same time. A journey
that adds stories quickly, like the whiteboard, takes a large block (hundreds) rather than twenty at a time, so it
does not run out again within the week (bead `context-grabber-0e04`: the whiteboard ran out on 2026-11-22 and agents
went back to picking IDs by hand, one of them reusing an ID an open PR already held).

## The pre-merge check

A recipe, run in the branch's checkout immediately before merging its PR: it fetches main and the branch as pushed
(the pipeline adds its own commits to the PR, so the local branch can be behind it), merges the two without touching
the checkout, and runs the story ID check on the stories of the merged result. When the checkout is behind the pushed
branch it says so and checks the pushed one, since that is what merges; a branch not pushed yet is checked as it is
locally. It fails when the merge conflicts or when the merged stories fail the check, naming each problem the way the
host rung does. It passes, and says so, otherwise.

## Acceptance criteria

- Two reservations started at once for the same journey print different IDs.
- An ID an open PR adds, an ID on main, an ID in the branch's own stories and an ID reserved earlier are skipped.
- A reservation older than 24 hours, or whose ID has reached main, no longer holds its ID.
- With the open PRs unreadable, it fails and prints no ID.
- With too few free IDs, it prints no ID; its message names the journey by its row's name, the next unused block
  above every journey's IDs and the free IDs every journey has left.
- Two branches that each pass the story ID check alone, but add the same ID, fail the pre-merge check; one that
  doesn't collide passes; one whose pushed commits add the colliding ID fails even when the checkout is behind them.
- The agent instructions say: new stories take their IDs from the reserve command, and the pre-merge check runs
  right before every merge.
