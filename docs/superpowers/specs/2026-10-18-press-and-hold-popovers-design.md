# Press and hold a tile: a popover of drawn icons

Igor, 2026-10-18 ([#391](https://github.com/idvorkin/context-grabber/issues/391), the follow-up to
[#383](https://github.com/idvorkin/context-grabber/issues/383)): *"I want a pop over w/Icons like the thing we have
... Nice Icons like the main window"*; *"Don't popover icons replace the hold menus? Aren't these the replacement?"*
He chose drawn art for every choice and left the rest to the recommendations ("You can make the decisions
yourself"). The blog's topics are their own spec change ([#392](https://github.com/idvorkin/context-grabber/issues/392))
and use the same popover.

## Summary

A tap on a home tile does what it always has. Holding a tile that has nearby variants opens a small popover pointing
at it, holding those variants as small drawn tiles with their names under them, like the home grid. Choosing one
opens it. The popover replaces the grey list menu the music tile had; there is no list menu anywhere.

## Goals

- One gesture for "the same thing, but that one": a preset, another mix, another mode, without opening a screen
  first.
- It looks like the home screen: drawn pictures, not a list of words.

## Non-goals

- A popover on every tile. A tile whose tap opens one screen, or another app, with no named variant inside gets none.
- Call Larry. A call starts the moment it is chosen, so a slipped finger would ring Larry, and the Call screen
  already has the voice picker.
- Rearranging, hiding or adding choices from the app.

## What Igor sees

**Holding.** Press and hold a tile with a popover and, after the usual iOS hold, the tile gives a light tick and a
popover opens beside it, its arrow pointing at the tile. Inside, the choices sit in a grid of small tiles (three to a
row), each with its drawn picture and a short name under it. Where a plain tap makes one of the choices (the Workout Supermix, Think of a card), it comes first; the timer's and breathing's tap opens their remembered preset ready, so their choices simply run in order.

**Choosing.** Tap a choice and the popover closes and that choice opens, exactly as if it had its own tile. A tap
outside the popover, or a swipe, closes it with nothing opened. Holding a tile with no popover does nothing, as
today: no lift, no preview.

**The tiles that get one, and their choices:**

| Tile | Choices, in order | What a choice does |
|---|---|---|
| Workout Supermix | Workout Supermix · Liked music · Feel Good Supermix | Opens that mix in YouTube Music (the browser without it), as the tap does; a mix that will not open shows the same copyable problem under the tiles |
| Gym Timer | 30 SEC · 1 MIN · 2 MIN · 5-1 · Custom | Opens the timer on that preset and starts it: the get-ready countdown is the moment to put the phone down. Custom is the remembered Custom workout |
| Box breathing | 8 s · 10 s · 12 s · 15 s | Opens breathing with that many seconds a side, for the remembered session length, and begins |
| Think of a card | Think of a card · A card face up · Drill the stack | Think of a card counts as the tap does; face up shows a card at once; Drill opens the stack drill |

**The pictures.** Each choice has drawn art in the same style as the home tiles: the Workout Supermix is the tile's
own kettlebell in headphones, Liked music a heart, Feel Good a sun; the card's three are a thought bubble over a
card, a face-up card and a target over a fan of cards. The timer's and breathing's presets are their number, large,
on the tile's own colour (the timer's red, breathing's teal), since a number is the clearest picture of "2 MIN". Until
a picture is drawn, the choice shows Apple's nearest symbol on its tile's colour, so nothing is ever blank.

**VoiceOver.** The tile keeps its tap. Its actions list each choice by name ("Gym Timer, 2 MIN"), so every choice is
reachable without the hold.

## Remembering

Nothing new. A preset chosen from the popover is the timer's or breathing's chosen preset afterwards, as choosing it
on its own screen would make it.

## Explaining itself

Each choice is logged as the same `ui` event its screen or link already writes, with `from: home_popover` and the
choice, and the popover's opening is logged with the tile, so a hold that opened nothing still shows in the log.

## Acceptance criteria

- Holding Workout Supermix, Gym Timer, Box breathing or Think of a card opens a popover of drawn choices pointing at
  the tile, the tap's own choice first where it is one; holding any other tile does nothing.
- Choosing *2 MIN* starts the timer on 2 MIN after its get-ready countdown; choosing *10 s* begins breathing at 10 s
  a side; choosing *Drill the stack* opens the drill; choosing *Liked music* opens his likes in YouTube Music.
- A tap outside closes the popover and opens nothing.
- A plain tap on each of these tiles does what it did before.
- VoiceOver reaches every choice from the tile's actions.
- The log has the popover opening and the choice, with `from: home_popover`.
