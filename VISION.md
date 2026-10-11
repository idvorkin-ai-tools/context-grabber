# Vision

`context-grabber` exists so that Igor has one front door to his day: it shows him and Larry, his AI coach, the week he actually lived rather than the one he remembers, and opens what he needs by the job he is doing.
It serves one person, Igor, with an iPhone in his pocket, a watch on his wrist and a coaching call to show up to.
It turns what the phone already knows, Health, places and the moments he chooses to note, into a humane mirror on the home screen, a context export Larry can read cold, and a launcher organised by Igor's jobs to be done rather than by app.
It owns the phone's honest picture of Igor's week, the phone's line to Larry, and the front door to the smaller apps he uses.

## A humane mirror

The mirror shows what happened without judging it: time-since and a quiet row of the week's days, never streak counts, and no red badges.
Capture stays implicit: Health and location fill the mirror on their own, and anything typed by hand is optional, never a daily chore.
A daily item turns green by itself when the phone already knows it happened, and a tap is only the fallback.
Glance time is the latency that matters: the home screen answers how the day is going at a look.
The home screen holds only what Igor uses, and everything else waits behind the cog rather than being deleted.

## The front door

It started life gathering as much context as it could; now it is also Igor's launcher.
The home screen is organised by what Igor is trying to do, not by which app does it, and the smaller apps he uses open, or are rebuilt, inside the door.
Because Igor sees it so often, it is the surface where Larry coaches him and reminds him what is important.
Each morning one quiet notification carries a passage from Igor's eulogy, from the role he has shown up as least lately.

## Feeding Larry

The line to Larry is live and two-way: what the phone learns reaches Larry as it happens, and what Larry sends back lands on the phone.
The export reads like a status memo a thoughtful person could advise on cold, with raw numbers as evidence, not the headline.
A Larry call is one tap away from the home screen, a widget or a Shortcut, and it survives the phone locking.
A live call comes first: anything else that wants the audio waits and yields.
During a call Larry can ask the phone for a slice of the week, a day's places or a night's sleep, and the app answers over the call's bridge.
Coaching comes from Larry: the app carries his reminders to the front door and does not invent advice of its own.

## Practice that reports back

The Gym Timer and box breathing earn their place because their sessions land back in the mirror, as a gym day or mindful minutes in Health.
Music keeps playing through a workout and only ducks around the cues.
The practice tools and the daily strip also run from the watch, with no phone needed.
Reading the camera roll on the device to notice which roles Igor showed up in is a maybe for later, not now.

## Evidence over guesses

A behaviour change updates its functional spec before the code, and the user stories are the only record of what the app does and where it was verified.
A change is verified on the cheapest rung that can see it, and says which rung.
A phone-only symptom gets the log line that would settle it before it gets a fix; a second guessed fix does not ship.
Every error Igor can see is copyable with its state, never a bare red string.
Bug reporting is BugKit's, and a bug in that code is fixed there.
Place and distance thresholds are checked against real location fixtures before they ship.

## One app, not two

The new app is the app; the old one is erased rather than kept running beside it.
What the old app did is folded into the native one deliberately, story by story, and the stories are what must stay true, not the old code, so logic is rewritten wherever a native design is better.
Nothing on the phone is lost when the old app goes: location history, known places, the journal, settings and widget state all carry over.

## Scope

It is not a fitness tracker, because Apple Health is one; not a habit tracker, because streaks would break it; not a journal app; and not a coach, because Larry is.
It is not a quantified-self dashboard: numbers are evidence, never the product.
It is not a memdeck trainer: magic shows up in the mirror, and drills live in their own app.
The Gym Timer times rounds; sets and weights belong to exercise-analyzer.
Larry's own work, his agents and PRs, stays in the Cockpit rather than on the home screen.
It is built from Igor's eulogy for Igor, not as a mirror for anyone else's.
It runs on Igor's iPhone, iPad and watch first; a web version is fine when it helps, and Android and Mac Catalyst are out.
Igor's private data travels only to his own devices, his own iCloud and Larry's bridge, and call diagnostics leave only as unlisted gists marked for deletion once read.

A change aligns when it makes the mirror truer at a glance, gives Larry better context, removes a step Igor would otherwise do by hand, or puts one of his jobs behind the front door.
A change should be resisted when it makes Igor feel behind, asks for daily logging, turns a number into the product, or adds a screen that feeds neither the mirror, Larry, nor a job Igor opens the door for.
