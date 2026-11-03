# Windows on the iPad

Igor, 2026-11-03 ([#634](https://github.com/idvorkin/context-grabber/issues/634), from the iPad): *"Let's support
multiple windows on iPad And maybe press and hold let me Open inbox and cockpit on different windows or any of them
really"*. He left the rest open; the choices below are the conservative ones.

## Summary

On an iPad, holding a home tile offers **New window**, and that screen opens in a window of its own, beside the home
window. Chat next to the Cockpit, a board next to Today. The app stays one app: one call, one problem report, one
log. A phone changes in no way at all.

## Goals

- Any two of Chat, Today, the Cockpit, Places, the boards and the card on screen at once.
- A second window can't break what the first is doing: above all a call or a board being drawn.
- An honest line about what stays in one window, and why.

## Non-goals

- Windows for the Gym Timer, Box breathing or the call screen. Each holds the phone's audio, and the rule that they
  don't talk over each other lives in how one window shows one of them at a time.
- Two windows of one screen. Two windows on the Chat list add nothing, the Cockpit's page can be in one place only,
  and one board drawn in two windows would overwrite itself.
- A home screen in every window.
- Anything on a phone.

## What Igor sees

**Opening.** Press and hold the Chat, Cockpit, Places, Whiteboard or card tile, or the Today card. A popover offers
*New window* (on the card tile, last after its own three choices). Choosing it opens the screen in a new window; the
home window stays as it was. Tiles that hold the audio offer no such thing.

**In the window.** It is the same screen as ever, with its Done, which closes the window. Closing it the system's way
is the same. The Cockpit's page outlives its window, as it outlives Done today. What was being drawn on a board is
saved as the window leaves. The card's home and lock screen widgets catch up as its window leaves, as they do when
the card closes at home. A Places window closed with its full-screen map up opens on the list next time.

**One place at a time.** With a screen in a window, tapping its tile brings that window forward, and so does a link, a
Shortcut or a notification for it: a notification's thread opens in the Chat window, a *Jump to board* on the board in
the Whiteboard window. If the home window is showing a screen when another window asks for that screen, it goes from
home first. A card window already open comes forward as it is: choosing *Drill the stack* or the tile's count there
starts neither, then or the next time the card opens.

**Another window of the app.** iPadOS can make a new window itself, from its own menus. With a home window up, that
window says home is open in another window and to hold a tile there. With no home window, it is the home window.

**A call.** A call starts, runs and ends as it does now, in the home window. Opening or closing other windows does
nothing to it. A board's microphone stops when a call starts, in whichever window the board is. Chat's dictation gives
way too.

**Links with no home window.** A link or a Shortcut for a screen that has no window brings the home window back and
shows it there.

**A relaunch.** iPadOS may bring back only a screen's window when the app starts. The home window then opens too, a
moment later, so there is always a way to the home screen after a launch.

**Coming back.** However many windows there are, the app counts one return to the front, so a refresh, a sync and the
archive's check run once.

**A report.** A shake or ⌘I opens the report over the window in front, with that window's picture, and names its
screen.

## What stays in one window

- **The Gym Timer, Box breathing, the call screen, the eulogy song's sheet, Settings and What's new** show only in the
  home window.
- **A link takes over the home window**, as it always has. A *Jump to board* from a Chat window, with the boards not in
  a window of their own, closes what the home window is showing to show the boards there, a running Gym Timer included.
  The home window comes forward as it happens, so the takeover is never out of sight.
- **The screen lock** is the app's, not a window's: a call or a workout keeps every window lit.
- **The gentle shake** can stop when one window goes to the background while another stays in front, until the app next
  comes back. A hard shake, ⌘I and the Report a problem tile still work. BugKit decides this, for the whole app.
- **A report from the home window can name the wrong screen** right after Today or the card opened or closed in another
  window. The picture is still of the window in front.
- **A report with two windows side by side can name either one's screen.** Both are active and iOS doesn't say which
  was shaken. With one window in front, it names that one.

## Acceptance criteria

- On an iPad, a hold on each of the six offers *New window*, and it opens that screen beside home.
- On an iPhone, the hold popovers and every screen are as they were.
- Asking for a screen already in a window opens no second window.
- A call survives opening, using and closing another window; so does a board's drawing.
- No screen shows in two windows at once.
- A window the app has closed, or the system has, leaves no trace: its tile opens it again as usual.
- A link, a Shortcut or a notification with the home window closed still lands somewhere.
- A link that lands in the home window, from another window in front, brings the home window forward.
- A card or Places window that closes leaves nothing behind: the card's widgets are current, the map is down, and a
  drill asked for while the card was in a window doesn't start later.
