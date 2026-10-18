# Scheduler

Labor scheduling and SMS fill for one entertainment venue. Crew never log in. The desk does. Payroll, and silos for other venues, come later. Rows carry `venue_id` from the start so a second venue has somewhere to attach.

Times are stored in UTC and shown in the venue time zone, including send windows and the evening reminder. The desk user's own zone is ignored.

## Stack

Rails 8, PostgreSQL, Hotwire, Solid Queue, Minitest. Twilio is the production messaging gateway. The test suite always uses `Messaging::FakeGateway`, even when `MESSAGING_ADAPTER` is set. Development defaults to `simulator`. Production uses `twilio` when `MESSAGING_ADAPTER=twilio`. The layout shows "Texts are not being sent." whenever the live gateway is not Twilio.

Outbound texts go through `Messaging::Deliver`. Inbound texts go through `Messaging::Receive`. The fill process does not mention Twilio. The webhook, the phone screen, and the tests are three callers of those two objects. `Deliver` and `Receive` arrive with the message history, not in this skeleton.

## Desk

A handful of users belong to one venue. Email and password. Development seed: `desk@example.com` / `password`, venue time zone `America/New_York`.

## Roster

An employee has a preferred name, legal name, mobile, email, notes, and an active flag. Nothing else until payroll.

Skills sit in categories. Audio, for example, contains FOH mixer, monitor mixer, RF, and deck audio. An employee has any number of skills. Each one has a level from 1 to 5 and a short note.

Employees have one venue-wide order. Filtering by skill uses that order. Dragging inside a template or a fill list overrides it after that.

A client has many shows. A show belongs to a client. A show has many calls. A call has a start, an end, a location, and a call type. Locations, call types, and position labels are lists the desk maintains.

A call is a list of slots. Headcount is the number of slots. Each slot has a position label. The label is for the desk. It is never sent to an employee, and it does not filter who can be booked. Skills are used only when building a list.

## Manual booking

The desk can put a person on a specific slot and set confirmation directly.

An assignment records:

- Source: manual, or the fill process that booked them.
- Confirmation: unconfirmed, confirmed by reply, confirmed by desk, or declined.
- A review flag, set when a YES carries extra words, or when they back out after being booked.
- A short note.

A YES from a fill process books the next open slot that process owns and sets confirmed by reply. The offer does not name the slot label. The booking text names the show, the time, and the place, includes the calendar link the first time they become confirmed, and tells them to reply NO later if they cannot make it. It does not leave a question open.

A manual assign can be marked confirmed by the desk, and then nobody is texted. Otherwise one confirmation text goes out inside the send window. YES confirms. NO backs them out. Silence leaves them on the slot.

Releasing a person keeps the history and reopens the slot. A person the desk removes does not page the bosses. A crew-initiated "I can't" does.

Someone already on another slot of the same call cannot be placed again until they are released. The desk can manually place someone who has a time conflict or a previous decline.

## Lists and status

Template lists are named, ordered groups of employees. Dragging a template into a process list adds names in template order and skips anyone already on that list. People who are currently booked are still added. Conflict is checked when their name is reached.

On the slot picker and on a fill-process list, each person shows one status:

- On this call, already on another slot
- Declined this call
- Time conflict, booked on an overlapping call
- Waiting on another text
- Available

The fill process only texts people who are available at that moment. Waiting and time-conflict names stay on the list and are tried again if that clears. Touching start and end times do not overlap. An unconfirmed assignment still counts as busy. A declined name and a name already on this call stay decided.

A process that reaches the end of its list with slots open waits in "needs more names." It keeps checking for names the desk adds and for people it skipped only because they were booked or waiting on another reply. It does not revive a NO or a backout.

## One open question

Each employee has at most one open question: a fill offer, a manual confirmation, or the evening reminder. YES and NO apply to that question. The message names the show, the time, and the place.

A second process on the same call does not text someone the first process has already asked. There is no priority setting. A simultaneous start is whoever records the send first. Their YES or NO is about the whole call, because the offer does not name the job. The other process moves to the next person and does not come back.

A process on a different call skips someone who already has a question open, leaves them on the list, and can ask once that question closes, unless the times then overlap.

YES with extra words books them, stores the words as the note, and flags the assignment for review. A bare YES or NO, ignoring case and trailing punctuation, is a clean answer. Any other reply is logged, the question stays open until it times out, and the desk sees the text.

A NO while a question is open answers that question only. Extra words are flagged and do not drop some other call.

## Normal fill

A process owns a set of open slots on one call. Two processes cannot own the same slot. The desk builds the ordered candidate list from a skill filter, a template, or both, then can drag to reorder.

The process texts enough available people to match the number of open slots, and skips anyone it cannot ask yet.

- A YES books one open slot. Other unanswered texts stay out. Nobody new is texted.
- A NO or a timeout leaves the slot empty, so the process asks the next available person.
- A late YES does not take a slot that already has an unanswered text out. If some open slot has no text out, they are booked onto it. If every remaining slot is waiting on a reply, they wait at the front of the line and are not texted again. The next NO or timeout books them. If the in-flight replies fill the call first, they are told the call is filled.

Offers and manual confirmations use the process send window. The window shows the venue default, with a checkbox to replace the start and end. Replies are accepted at any time. Timers keep running outside the window, and the next text waits until the window opens. Boss alerts go out immediately.

## Emergency fill

A process setting, separate from the ordered walk. Each step texts the next group, using that process's step size, and waits that process's step time before widening. Earlier texts stay live. The first YES replies fill whatever slots are still open, including a slow reply from an earlier step. Each message says how many spots are still open and that the first YES replies get them, and it says this is a first-response fill. When the spots are gone, later YES replies are told the call is filled and are not put back in line.

Someone booked, already a NO on this call, or holding an open question is not part of the blast. The step continues down the list until that many texts are actually out.

## Backing out

When no question is open, a later NO is a decline:

- One upcoming call: they come off it, the slot reopens, and they are told which show and time they left. They are not asked about that call again. Their time is free for other work. Bosses get the warning. If that slot's process is still filling, it continues. If the process already finished, its own setting either resumes from where the list stopped or leaves a warning on the call.
- Several upcoming calls: one text lists them, soonest first, and asks for a number. That list is the open question. If they never pick, nothing changes.
- Nothing upcoming: the message stays on their thread.

The evening reminder's NO is unambiguous because that reminder is the open question for that call.

## Evening reminder

Once, at the venue's reminder time, to whoever is on the next day's calls at that moment. People added later, and calls created after that time, do not get one. A same-day call does not get one.

The text names the show, the time, and the place. It asks them to confirm. The call shows whether it was sent and how they replied. No reply leaves them on the call. The unanswered reminder closes after two hours so other calls can text them. Silence does not page the bosses. "I can't" backs them out and texts the bosses.

The boss list is a set of mobile numbers on the venue. The warning names the employee, the show, the time, and the slot label.

## Calendar

The booking text includes a link to an `.ics` file: show name, start, end, and location, in the venue time zone. No slot label. The link is sent the first time they become confirmed, including when the desk marks them confirmed. A later reminder YES does not send it again. Their phone keeps its own copy. A backout or a time change does not update that copy. The "you're off this call" text is the notice.

## Phone screen

A page in this app, shown while the adapter is the simulator. The left column is every employee, most recent message first, with their open-question state. The right side is that thread. A reply box, plus YES, NO, and a free-text reply, calls `Receive`. Demo controls run the real jobs early: time out this offer, run the next emergency step, fire the evening reminder. The server clock stays put.

## Logging

Every fill step is an append-only log: who was texted, when, the timeout, the reply, the assignment, or the skip. The employee page shows that person's full SMS thread and can send a one-off text. A one-off text does not open a question. While a question is open, the next YES or NO still belongs to that question.

## Out of this version

Payroll fields, pay rates, and hours. More than one venue in the interface. A crew login. iMessage. Reply codes.
