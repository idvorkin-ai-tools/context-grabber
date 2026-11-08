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
- A home screen in every window. A new window offers the screens that can have one (above), not the whole of home.
- Anything on a phone.

## What Igor sees

**Opening.** Press and hold the Chat, Cockpit, Places, Whiteboard or card tile, or the Today card. A popover offers
*New window* (on the card tile, last after its own three choices). Choosing it opens the screen in a new window; the
home window stays as it was. Tiles that hold the audio offer no such thing.

**In the window.** It is the same screen as ever, with its Done, which closes the window. Closing it the system's way
is the same. The Cockpit's page outlives its window, as it outlives Done today. What was being drawn on a board is
saved as the window leaves. The card's home and lock screen widgets catch up as its window leaves, as they do when
the card closes at home. A Places window closed with its full-screen map up opens on the list next time.

**Its name.** Igor, 2026-11-03 ([#661](https://github.com/idvorkin/context-grabber/issues/661), from the iPad, in the
Chat window): *"Let's name the windows so this window should be called chat if I opened chat Maybe just name the window
based on what it's currently active"*. Each window tells iPadOS what it is showing, under the name that screen's home
tile already has: Chat, Today, Cockpit, Places, Whiteboard, Think of a card. iPadOS shows that name where it tells one
window of an app from another, such as the app switcher, Stage Manager and the window menus; which of those show it,
and how, is iPadOS's own choice.

The home window on the home grid is called Home. When it shows something else the name follows, and it returns to Home
when that closes: a Gym Timer, Box breathing, a call (*Call Larry*), Settings, the eulogy song's sheet (*Eulogy song*)
and What's new are named as their tiles and rows are, as are the six above when they are up at home. A screen's window
shows only its one screen, so its name stays. What is opened inside a screen doesn't rename the window: a thread in
Chat is still Chat, a metric's week over Today is still Today.

A window that says home is open in another window has no screen to be named after, and the app gives it no name. On a
phone the app names nothing.

**One place at a time.** With a screen in a window, tapping its tile brings that window forward, and so does a link, a
Shortcut or a notification for it: a notification's thread opens in the Chat window, a *Jump to board* on the board in
the Whiteboard window. If the home window is showing a screen when another window asks for that screen, it goes from
home first. A card window already open comes forward as it is: choosing *Drill the stack* or the tile's count there
starts neither, then or the next time the card opens.

**Another window of the app.** iPadOS can make a new window itself, from its own menus, and on the Mac File > New Window
(Command+N) does. With no home window, it is the home window. With a home window up (Igor, 2026-11-07, #782, from the
Mac: *"If I make a new window, start on the main page and let me select a new thing"*), it starts as a short version of
home: the screens that can have a window of their own, as home's tiles with their names and icons, in the order home
shows them (the Today card first when home shows it), and nothing home hides. Choosing one turns this window into that
screen's window. If that screen is already in a window, that window comes forward instead and this one closes, so no
screen shows twice; if the home window is showing it, it goes from home first, as a hold's *New window* does. The
screens that hold the audio (the Gym Timer, Box breathing, a call), Settings and the rest of home aren't offered: they
stay in the home window. Closing this window without choosing leaves everything as it was.

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
- A screen's window is named for its screen, by the name on its home tile, from the moment it opens.
- The home window is named Home on the home grid, takes the name of what it shows when that goes up, and is Home again
  when that closes. A screen opening or closing in another window doesn't rename it.
- A window choosing what to show has no name from the app. Choosing Chat there makes it the Chat window, named Chat;
  choosing a screen already in a window brings that window forward and closes this one.
- On the Mac, Command+N with home open opens a window offering the screens home shows that can have a window, in home's
  order, and nothing else.
- On an iPhone the app names no window.
- A card or Places window that closes leaves nothing behind: the card's widgets are current, the map is down, and a
  drill asked for while the card was in a window doesn't start later.
