# Scheduler

Labor scheduling and SMS fill for one entertainment venue. Crew never log in. The desk does. Payroll, and silos for other venues, come later. Rows carry `venue_id` from the start so a second venue has somewhere to attach.

Times are stored in UTC and shown in the venue time zone, including send windows and the evening reminder. The desk user's own zone is ignored.

## Stack

Rails 8, PostgreSQL, Hotwire, Solid Queue, Minitest. Twilio is the production messaging gateway. The test suite always uses `Messaging::FakeGateway`, even when `MESSAGING_ADAPTER` is set. Development defaults to `simulator`. Production uses `twilio` when `MESSAGING_ADAPTER=twilio`. The layout shows "Texts are not being sent." whenever the live gateway is not Twilio.

Outbound texts go through `Messaging::Deliver`. Inbound texts go through `Messaging::Receive`. The fill process does not mention Twilio. The webhook, the phone screen, and the tests are three callers of those two objects. `Deliver` and `Receive` arrive with the message history, not in this skeleton.

## Desk

A handful of users belong to one venue. Email and password. Development seed: `desk@example.com` / `password`, venue time zone `America/New_York`. Open desk pages share one live stream and poll; new pages inherit that from the layout.

## Roster

An employee has a last name, a first name, an optional preferred name, mobile, email, notes, and an active flag. The desk sees "Last, First", or "Last, Preferred" when a preferred name is set. Nothing else until payroll.

Skills sit in categories. Audio, for example, contains FOH mixer, monitor mixer, RF, and deck audio. An employee has any number of skills. Each one has a level from 1 to 5 and a short note.

Employees have one venue-wide order. Filtering by skill uses that order. Dragging inside a template or a fill list overrides it after that.

A client has many shows. A show belongs to a client. A show has many calls. A call has a start, an end, a location, and a call type. Locations, call types, and position labels are lists the desk maintains.

A call is a list of slots. Headcount is the number of slots. Each slot has a position label. The label is for the desk. It is never sent to an employee, and it does not filter who can be booked. Skills are used only when building a list.

A slot can link to one slot on another call of the same show. Creating a call can copy another call's slots and link each new slot to its source. The desk can link or unlink a pair later. A fill that owns a linked open slot, or a manual Ask on a linked slot, offers both schedules in one text; YES books both open sides; NO declines that ask or fill only. Unlink before or after booking when someone should work only one of the two.

## Manual booking

The desk can put a person on a specific slot and set confirmation directly.

An assignment records:

- Source: manual, or the fill process that booked them.
- Confirmation: unconfirmed, confirmed by reply, confirmed by desk, or declined.
- A review flag, set when a YES carries extra words, or when they back out after being booked.
- A short note.

A YES from a fill process books the next open slot that process owns and sets confirmed by reply. The offer does not name the slot label. The booking text names the show, the time, and the place, includes the calendar link the first time they become confirmed, and tells them to reply NO later if they cannot make it. It does not leave a question open.

A manual assign marked confirmed by the desk sends the same booking text a YES would send. Putting an unconfirmed name on a slot does not text them, and the slot stays open. Ask sends one confirmation text inside the send window, or holds it until the question they are already answering is resolved. YES confirms. NO backs them out. Silence leaves them on the slot. Until Ask, the name can be changed, and the old name is dropped with no cancelled history. Once a text has gone out, or the person is confirmed or declined, the name stays locked until Cancel. Ask and the cancel icon share a column next to the name so the dropdown width does not change. Cancel asks before it runs. Cancel texts them that they are off the call, keeps the history as Cancelled, and does not page the bosses.

Releasing a person from the assignment detail keeps the history and reopens the slot without a cancellation text. A person the desk removes does not page the bosses. A crew-initiated "I can't" does. A slot can be removed while it is empty or only has an unasked name. It cannot be removed while a text is out, the person is confirmed or declined, or the slot is on a fill.

Someone already on another slot of the same call cannot be placed again until they are released. The desk can manually place someone who has a time conflict or a previous decline.

## Lists and status

Template lists are named, ordered groups of employees. Each venue has one default list. Dragging a template into a process list adds names in template order and skips anyone already on that list. People who are currently booked are still added. Conflict is checked when their name is reached.

Open slots use a red badge. Prior declines and cancels on a slot are a short list under the status.

The slot assign menu lists employee lists as nested flyouts, keeps search on the full roster, and strikes through unavailable people with a badge for decline, conflict, or a text already out. They can still be put back on the slot. The fill source tree on the left uses the same marks.

On the slot picker and on a fill-process list, each person shows one status:

- On this call, already on another slot
- Declined this call
- Time conflict, booked on an overlapping call
- Waiting for a reply, a fill or ask already out for this call
- Waiting on another text, a question about a different call
- Available

Status color is split by hue: slate for open, gold for waiting, lime for confirmed, coral for declined, violet for timed out. Selecting a row draws an ink outline and leaves the status wash in place.

The fill process only texts people who are available at that moment. Waiting and time-conflict names stay on the list and are tried again if that clears. Touching start and end times do not overlap. An unconfirmed assignment still counts as busy. A declined name and a name already on this call stay decided.

A process that reaches the end of its list with slots open waits in "needs more names." It keeps checking for names the desk adds and for people it skipped only because they were booked or waiting on another reply. It does not revive a NO or a backout. A check that finds the same situation again does not add another log line. The existing line notes how many times it was repeated.

## One question at a time

An employee is only asked one question at a time. Further questions wait in the order they were added: a manual confirmation, a fill offer, a choice, or the evening reminder. YES and NO apply to the question that was asked. The message names the show, the time, and the place.

When another question is added while one is already out, a follow-on goes right away. It says how many questions are waiting and asks the current one again. The next question is sent when the current one is answered, times out, or is cleared. The offer timeout starts when that text actually goes out.

A question whose call has already ended is cleared, without booking, declining, or texting them off. A choice is cleared once every call on it has ended. That check also runs every hour.

A second process on the same call does not text someone the first process has already asked. There is no priority setting. A simultaneous start is whoever records the send first. Their YES or NO is about the whole call, because the offer does not name the job. The other process moves to the next person and does not come back.

A process on a different call skips someone who already has a question open, leaves them on the list, and can ask once that question closes, unless the times then overlap.

YES with extra words books them, stores the words as the note, and flags the assignment for review. A bare YES or NO, ignoring case and trailing punctuation, is a clean answer. Any other reply is logged, the question stays open until it times out, and the desk sees the text.

A NO while a question is open answers that question only. Extra words are flagged and do not drop some other call.

## Normal fill

A process owns a set of open slots on one call. Two processes cannot own the same slot. Each fill on a call gets a number that stays on that fill. The collapsed fill list shows that number, a count of slots by position, a color-and-icon badge for new, running, paused, needs names, or complete, and a short line for how far the fill has got. The slot list shows the same fill number next to the slot status.

The desk can check slots, check all of them, and drag slots to reorder. The colored index column is the slot's place in that order and carries the status color. The top of the call is a banner of slot count, confirmed, awaiting a reply, and slots on a fill. Every desk page stays current over the venue live stream and a short poll; a dropped connection shows a blocking warning and keeps trying until the page can reload. A refresh keeps the current slot and fill selection. The desk builds the ordered candidate list from a skill filter, a template, or both, then can drag to reorder.

The process texts enough available people to match the number of open slots, and skips anyone it cannot ask yet.

- A YES books one open slot. Other unanswered texts stay out. Nobody new is texted.
- A NO or a timeout leaves the slot empty, so the process asks the next available person. The timeout is a job scheduled when the text goes out. It fires when the minutes are up. The phone button runs that same job early.
- A late YES does not take a slot that already has an unanswered text out. If some open slot has no text out, they are booked onto it. If every remaining slot is waiting on a reply, they wait at the front of the line and are not texted again. The next NO or timeout books them. If the in-flight replies fill the call first, they are told the call is filled.

Offers and manual confirmations use the process send window. The window shows the venue default, with a checkbox to replace the start and end. Replies are accepted at any time. Timers keep running outside the window, and the next text waits until the window opens. Boss alerts go out immediately.

The desk starts a fill when the list is ready. Stopping it holds the next text. If a text is still out, the desk has to acknowledge that the offer stays live and a YES can still book. Starting it again continues down the list. A fill that is not running can be deleted. Its slots stay on the call. The fill log notes when that fill was created, started, or paused. Starting or pausing also writes a line on the call audit log.

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

The venue keeps an append-only audit log. A line has an actor (a desk user, a fill, an employee, or a named job) and a link to the object it touched. Putting a name on a slot is not logged until they are asked or booked. Reordering is not logged. The fill walk (who was texted, skipped, parked, or is waiting) stays on that fill's own log. The call page shows only slot outcomes: a name being asked or landing on a slot, or coming off it. That log fills the rest of the page. The Audit page lists those same venue lines.

The employee page shows that person's full SMS thread and can send a one-off text. A one-off text does not open a question. While a question is open, the next YES or NO still belongs to that question.

## Out of this version

Payroll fields, pay rates, and hours. More than one venue in the interface. A crew login. iMessage. Reply codes.
