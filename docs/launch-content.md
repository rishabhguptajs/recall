# Recall launch content

Written 2026-10-24. Covers the week of Tue Oct 27 to Mon Nov 2. All times are IST.

## Read this first: things I changed from your brief

1. **Install steps.** "Right-click, Open" does not work on macOS 15 (Sequoia) and later. Your own README and site say so. Every post below uses the real steps: open the app, click Done, then System Settings > Privacy & Security > Open Anyway, then your password. Right-click > Open still works on macOS 14, and the posts say that too.
2. **Hotkey.** The default is ⌥Space, not a generic "one hotkey". It is also a common Alfred/Raycast hotkey, so expect "it conflicts". It can be changed in Settings > General.
3. **Auto-updates.** Update checks are off by default. The posts say "update checks are off until you turn them on", which also helps the privacy case. They do not say "auto-updates".
4. **Privacy wording.** Your brief says the server never sees the license key. It does see it once: activation sends the key, the Worker passes it to Dodo Payments to check, and only a SHA-256 hash is stored. The trial endpoint also keeps a keyed per-day HMAC of the network prefix to cap abuse. The replies say this plainly. A commenter who reads your README will find it anyway.
5. **Price.** $19 is the early-bird price, then $29, one-time, one license for 3 Macs. The site already says this.
6. **Requirements.** Apple Silicon only, macOS 14+, English only. Intel users will ask first, so every Reddit post says it up front.
7. **Not open source.** The posts never say "read the code". The privacy answer is "run Little Snitch or LuLu and watch".
8. **No build-time claim.** The repo's history starts 2026-10-22, which is not your real timeline. I left out "built in X weeks" because r/macapps distrusts anything that looks like a weekend build.
9. **Reddit video posts have no body text.** So the Reddit posts below are text posts (the story) with the poster image attached and the film linked in the text. If you prefer a video post, paste the story as the first comment.

## Is there another app that does exactly this?

Not exactly, as far as I could find, but parts of it exist. Most of what I found comes from vendor blogs, so check each one before you quote it.

- **Filect**: semantic search of file contents (with OCR) on your Mac. Not a launcher. Closest on search.
- **Fenn**: finds content inside PDFs, slides, audio and screenshots.
- **Pastea, TypeFire**: clipboard history with OCR on copied images. TypeFire is $18 once.
- **Raycast, Alfred**: launchers with clipboard history, but no meaning-based search.
- **Spotlight**: indexes file contents. Check what macOS 26 does with clipboard and screenshots before you make any claim about it.

So never write "the only app that...". The defensible line is: meaning search across files, screenshot text and clipboard in one local panel, with a free tier and a one-time price.

## 1. Launch plan

**Goal for the week:** get people to download and run the 14-day trial, and learn what breaks. Revenue this week is a bonus.

**The constraints that shape the plan**
- Your Reddit account has about 5 to 6 karma. Many subs auto-remove posts from accounts like that, and r/macapps reportedly wants about 10 karma plus mod permission, and limits developers to one post per 30 days. I couldn't open any subreddit's rules page, so every rule below is from third-party summaries. Read each sidebar before posting.
- Your X following is 35, so threads won't travel by themselves. Reach comes from replying in other people's Mac/Raycast/Spotlight threads, and from quote-posting the Raegent post from your personal account. Premium helps replies get seen.
- Don't post the same text in many subs on one day from a young account. Reddit and its spam filters flag the same domain repeating across communities, and that can hurt raegent.com for every later post. One sub per day, each post written for that sub.

**Before launch (Sat Oct 24 to Mon Oct 26)**
- Sat: send the r/macapps modmail (draft below). Read the sidebars of r/SideProject, r/MacOS, r/indiehackers and r/macapps, and note the karma and flair rules.
- Sat to Mon: spend 20 minutes a day leaving useful comments in r/macapps, r/MacOS and r/SideProject. Answer questions about finding files, screenshots and clipboard managers. No links. Aim for 20+ karma before Tuesday.
- Mon: do a clean-Mac install test with the exact steps in the posts, on macOS 14 and 15 if you can. Check the download link, the Open Anyway steps and the trial starting.

**Launch week**

| Day (IST) | Post | Video, uploaded natively | Time (IST) |
|---|---|---|---|
| Tue Oct 27 | X thread, personal | Square cut, `Recall-Launch-1x1-1080-60.mp4` (30 s) | 18:00 |
| Tue Oct 27 | X post, Raegent | Punch cut, `Recall-Punch-16x9-1080p60.mp4` (18 s) | 18:20 |
| Tue Oct 27 | r/SideProject | Poster image, plus the 22.8 s short linked in the text | 19:00 |
| Tue Oct 27 | Personal account quote-posts Raegent | none | 19:15 |
| Wed Oct 28 | r/indiehackers | none (poster image) | 18:30 |
| Thu Oct 29 | r/macapps (only if the mods said yes) | Short cut `Recall-Launch-16x9-Short-1080p60.mp4` as a video post, story as first comment | 18:00 |
| Fri Oct 30 | r/MacOS | Poster image only | 18:30 |
| Sat Oct 31, Sun Nov 1 | No new posts. Reply to everything, fix what people hit, ship a point release if needed. | | |
| Mon Nov 2 | X, Raegent: the full film plus what changed since launch | `Recall-Launch-16x9-1080p60.mp4` (57.6 s) | 19:30 |

**Timing notes.** US mornings (8 to 10am ET) are the best window for both Reddit and X, and that is 17:30 to 19:30 IST while the US is on daylight time. US daylight time ends Sunday Nov 1, so from Monday Nov 2 the same slot is one hour later in IST, which is why Monday is 19:00. Everything fits inside your 10am to 2am day. If a post gets no traction in the first hour, don't delete and repost. Reply to the comments you have and leave it.

**Which video where.** The cloud links you gave me don't embed on X or Reddit, so "attach" means downloading the file and uploading it to the post. The local files are in `video/launch/out/`. The Cloudflare short and film should be the same files as the 22.8 s short and the 57.6 s master. Check before you upload. The square and vertical cuts and the Punch cut exist locally but aren't on Cloudflare, which is fine because you upload them directly.

**What to measure.** `scripts/stats.sh` shows downloads per version, update checks and Pro activations. It can't tell you which post a download came from. If your site has analytics, use links like `raegent.com/recall?ref=reddit-sideproject` so you can see sources. Rough targets, which are guesses: 200 downloads and 5 paid in week one. If one sub brings 50 downloads and another brings none, that is the useful result.

**Risks.**
- *Posts removed by karma or rules.* Mitigation: warm-up comments, modmail first, start with the permissive subs.
- *The unnotarized warning scares people off.* Mitigation: say it in the first screen of every post, with the steps.
- *A privacy claim gets picked apart.* Mitigation: the replies below state exactly what the server stores. Don't round it up to "nothing".

## 2. X

### Personal account: launch thread

**Hook options for tweet 1.**

Option A (story first):
> I kept losing things on my Mac that I knew I'd seen. A screenshot of a pricing page. A link I copied last week. A PDF about visa rules.
>
> So I made a search that finds them by what's in them. It's called Recall.

Option B (problem first):
> I never remember filenames. I remember "that PDF about visa rules."
>
> So I made a Mac app that searches the way I remember: files, screenshots and clipboard, by meaning, all on the Mac.

I'd pick A. B is shorter and works better if you want to post it as a standalone later. Attach the square cut to tweet 1.

**Tweet 2**
> Spotlight wants the name. My clipboard history dropped things after a while. Screenshots are just "Screenshot 2026-09-14 at 11.02.48".
>
> What I remember is what the thing was about. I wanted one box that works from that.

**Tweet 3**
> Press ⌥Space and type something vague. It searches files, screenshots (it reads the text in them) and clipboard history together.
>
> Keyword search plus meaning search, using a small model bundled in the app. About 5 to 7 ms a query on my Mac.

**Tweet 4**
> A real one from my Mac: I typed "pricing table". The top result was a screenshot that only says "Plans & Billing $29/mo".
>
> A basic on-device approach ranked that same screenshot 35th. That gap is why I used a proper model.

**Tweet 5**
> No account, nothing uploaded. Files, searches and clipboard stay on the Mac.
>
> The only network use: the trial/license check (anonymous device ID), and update checks, which are off until you turn them on.
>
> It's closed source, so don't trust me. Watch it with Little Snitch.

**Tweet 6**
> The boring parts. Apple Silicon only, macOS 14+, English.
>
> It's not notarized yet. On macOS 15+: open it, click Done, then System Settings > Privacy & Security > Open Anyway.
>
> Free searches files and 7 days of clipboard. Every install gets 14 days of Pro, no signup, no card.

**Tweet 7**
> Pro is $19 once (early bird, then $29), for up to 3 Macs.
>
> raegent.com/recall
>
> If you try it, tell me what you searched for first and whether it found it.

Put the link in tweet 7 and not tweet 1, since X tends to show tweets with links to fewer people.

**Notes.** Don't use hashtags. Post it from the account with Premium so replies rank. After posting, reply to your own tweet 1 with the 57 s film link only if someone asks for more.

**Best time:** Tue Oct 27, 18:00 IST. **Video:** square cut on tweet 1.

### Raegent account: polished post

> Recall searches your whole Mac by what's in things, not what they're called.
>
> Files, screenshots and clipboard history, from one hotkey. The meaning search runs on your Mac. Nothing is uploaded.
>
> 14-day Pro trial on install, no signup. Apple Silicon, macOS 14+.
>
> raegent.com/recall

Reply to it:
> Recall isn't notarized yet, so macOS warns on first open. Click Done, then System Settings > Privacy & Security > Open Anyway. Steps and pricing are on the page.

**Best time:** Tue Oct 27, 18:20 IST. **Video:** the Punch cut (18 s). It differs from the personal thread's video, so the two posts don't look like duplicates.

Then at 19:15 post from your personal account a quote of the Raegent post: "Shipped this today. It's the thing I wanted every time I couldn't find a screenshot." Keep it that short.

**Mon Nov 2 follow-up, Raegent:**
> The Recall launch film, 57 seconds, made in code. One week in: [a real number or one thing people found that surprised you]. raegent.com/recall

Fill the bracket with something real. If you don't have one, don't post this.

## 3. Reddit

I couldn't open any of these rules pages, so what follows is from third-party summaries and may be out of date. Read each sidebar, check flair requirements, and disclose that you made it in every post.

| Sub | What I found | Fit |
|---|---|---|
| r/SideProject | Reported as the most open to self-promotion. Low-effort drops with no explanation get removed. | Good first post |
| r/macapps | Reportedly needs mod permission or a designated thread, about 10 karma, and one developer post per 30 days. Likes short posts with the official link and clear flair. | Best audience, hardest rules. Modmail first. |
| r/indiehackers | Feedback-oriented. Pricing and launch posts fit. | Good |
| r/MacOS | Rules not confirmed. Likely strict on self-promotion. | Try, low odds. Written as a question. |
| r/apple | Generally hostile to self-promotion. | Skip |

### Modmail for r/macapps (send Sat Oct 24)

> Hi mods, I'm the developer of Recall, a menu-bar app that searches files, screenshots and clipboard history by meaning, entirely on the Mac. It has a 14-day Pro trial, then a free tier, and Pro is a one-time purchase.
>
> Before I post anything, which do you prefer: a developer post with the right flair, or the megathread? I'll say I made it, link the official site, and cover the fact that it isn't notarized yet. Happy to follow whatever format you want.

### r/SideProject

**Title:** I kept losing screenshots and copied links on my Mac, so I built a local search for all of it

**Body:**

> I save a lot of things and find almost none of them again. Screenshots named "Screenshot 2026-09-14 at 11.02.48", links I copied and lost, PDFs I know I downloaded but can't name. I never remember the filename. I remember what it was about: "the PDF about visa rules", "the screenshot with the billing plans".
>
> So I built Recall, a menu-bar app for Mac. You press ⌥Space, type roughly what you remember, and it searches files, screenshots (it reads the text inside them) and clipboard history together.
>
> How it works: it matches keywords and also meaning, using a small model that ships inside the app and runs on the CPU. A query takes about 5 to 7 ms on my Mac, and the index for around 1,400 items is about 90 MB.
>
> One test I liked: on my own ~280 screenshots, "pricing table" returns a screenshot that only says "Plans & Billing $29/mo" first. A basic on-device approach ranked it 35th, so I used a proper model.
>
> There's no account and nothing is uploaded. The only network use is the trial/license check, which sends an anonymous device ID, and update checks, which are off until you turn them on. It's closed source, so if you care, run Little Snitch and watch.
>
> Things you should know before trying it:
> - Apple Silicon only, macOS 14 or later, English only.
> - It isn't notarized yet, so macOS warns you the first time. On macOS 15+: open it, click Done, then System Settings > Privacy & Security > Open Anyway, enter your password. On macOS 14, right-click > Open works.
> - Free searches files (Desktop, Documents, Downloads) and 7 days of clipboard. Every install gets all of Pro for 14 days automatically, no signup, no card. After that, Pro is $19 once (early bird, then $29) for up to 3 Macs. Pro adds screenshot search, extra folders and longer clipboard history.
>
> Site: raegent.com/recall. Film (57 s): https://recall-license.rishabhgupta4523.workers.dev/media/recall-film-v1.mp4
>
> I made it, so take that into account. I'd like to know what you'd search for that it doesn't find.

**Attach:** the poster image as the post image. **Best time:** Tue Oct 27, 19:00 IST. If the sub supports it, add the 22.8 s short as a native video in a comment or as a second post only if the mods allow.

### r/macapps (only after the mods answer)

**Title:** Recall: search files, screenshots and clipboard by meaning, all on-device (dev here, 14-day Pro trial)

Use the flair the mods tell you to use.

**Body:**

> Disclosure: I'm the developer.
>
> The problem I wanted to fix: I remember what a file, screenshot or copied link was about, not what it was called. Spotlight wants the name, and my clipboard history forgot things.
>
> Recall is a menu-bar app. ⌥Space (changeable in Settings) opens a panel. Type something vague and it searches files, screenshots and clipboard together. Tabs for All, Files, Screenshots and Clipboard. Hold ⌘Y to peek at a result, ⌘1 to ⌘4 switch tabs, ⌥↩ copies the path, ⌘⌫ moves a file to the Trash.
>
> Search matches keywords and meaning, with a small model bundled in the app. Nothing leaves the Mac: no account, no telemetry. Network use is limited to the trial/license check (anonymous device ID, and your key once at activation) and update checks, which are off by default.
>
> Pricing: free tier covers files plus 7 days of clipboard. Every install gets 14 days of Pro automatically, no signup, no card. Pro is $19 one-time (early bird, then $29), up to 3 Macs, and adds screenshot text search, extra folders and longer clipboard history. When Pro ends, nothing is deleted. It's just hidden until you activate.
>
> Honest limits: Apple Silicon only, macOS 14+, English only. It's closed source. And it is not notarized yet, because I haven't paid for the Apple developer account. On macOS 15+, open it, click Done, then System Settings > Privacy & Security > Open Anyway. I understand if that's a deal-breaker.
>
> Site: raegent.com/recall. Happy to answer anything, including about the privacy details.

**Video:** the 22.8 s short. **Best time:** Thu Oct 29, 18:00 IST, only if permitted.

### r/indiehackers

**Title:** Shipping a paid, local-only Mac app with an automatic 14-day trial and no signup. Here's the setup, tell me what's wrong with it

**Body:**

> I'm launching Recall this week, a Mac menu-bar app that searches files, screenshots and clipboard history by meaning, on-device. The part I'd like feedback on is the pricing and trial.
>
> - **Trial:** every install gets all of Pro for 14 days, automatically. No signup, no card. It's tied to the Mac, so reinstalling doesn't restart it.
> - **Free tier:** file search plus 7 days of clipboard. Screenshot search, extra folders and longer clipboard history are Pro.
> - **Price:** $19 one-time as an early-bird price, then $29. One license for 3 Macs. No subscription, because there's no cloud cost to cover.
> - **The weak spot:** it isn't notarized, because I haven't paid for the developer account yet. macOS shows a warning, and on macOS 15+ people have to go through Privacy & Security > Open Anyway. I expect this to cost me installs.
>
> What I don't know: whether a 14-day trial is long enough for people to try screenshot search, and whether the early-bird price should have an end date. If you've sold a one-time Mac app, I'd like to hear what you'd change.
>
> It's raegent.com/recall if you want to see it. I made it.

**Best time:** Wed Oct 28, 18:30 IST. **Video:** none, poster image only.

### r/MacOS

**Title:** How do you find a screenshot from three weeks ago?

**Body:**

> I take a lot of screenshots, and a few weeks later I can't find any of them because they're all named "Screenshot 2026-09-14 at 11.02.48." Spotlight doesn't help when I only remember what the screenshot said. Same problem with things I copied and lost.
>
> What do you do? Folders, a naming habit, an app?
>
> I got annoyed enough to build my own: Recall, a menu-bar app that searches files, screenshots and clipboard by meaning, on the Mac. I'm the developer, so take that for what it is. Apple Silicon, macOS 14+, not notarized yet (so macOS warns on first open), free tier plus a 14-day Pro trial. raegent.com/recall
>
> I'm more interested in how you solve this than in whether you try it.

**Best time:** Fri Oct 30, 18:30 IST. **Video:** poster image only. If the mods remove it, don't argue. Post your question again in the weekly help thread without the link.

## 4. Replies to the likely comments

Paste these as a starting point and change them to match how the person asked.

**"How is this different from Spotlight, Raycast or Alfred?"**
> Fair question. I still use a launcher, and Recall doesn't replace one. Raycast and Alfred launch apps and run extensions, and both have clipboard history. Spotlight indexes file contents, so if it finds things for you, great.
>
> What Recall does that I couldn't get is search by meaning across files, screenshot text and clipboard in one panel, on the Mac. Type "pricing table" and it finds a screenshot that only says "Plans & Billing". If you mostly search by exact name, you won't need it.
>
> If ⌥Space clashes with your launcher, you can change the hotkey in Settings > General.

**"Why isn't it notarized?"**
> Because I haven't paid for the Apple developer account, $99 a year, which notarization requires. It's signed with my own certificate, so macOS warns on first open.
>
> macOS 15+: open it, click Done, go to System Settings > Privacy & Security, click Open Anyway next to the Recall message, enter your password. macOS 14: right-click > Open works.
>
> If an app that reads your files shouldn't ask you to do that, I get it. I'd like to notarize it and will once sales cover the cost. [Edit this sentence if that isn't true.]

**"Is it really private?"**
> Here's what leaves the Mac, so you don't have to take my word for "nothing":
>
> - Indexing, OCR, meaning search and clipboard history run locally. No account.
> - Trial and Pro: the app sends an anonymous device ID, which is a salted hash of the Mac's hardware ID. For Pro activation it also sends your license key once. My server passes the key to Dodo Payments to check it and stores only a hash of it. To limit trial abuse the server also keeps a hash of your network address that can't be linked across days.
> - Update checks: off by default. When on, they send only the app version.
> - After the trial, the free tier never contacts my server.
>
> It isn't open source, so I can't tell you to read the code. Run Little Snitch or LuLu and watch what it connects to. Files, searches and clipboard contents never leave.

**"Why is it paid?"**
> Free covers file search and 7 days of clipboard history. Pro adds screenshot search, extra folders and longer clipboard history. Every install gets 14 days of Pro to try it first.
>
> It's one-time: $19 as an early-bird price, then $29, up to 3 Macs. No subscription because there's no cloud to pay for. It's closed source, and sales are what pay for me to keep fixing it.

**Extra replies**

*"Does it work on Intel?"*
> No, Apple Silicon only (M1 or later), macOS 14+. English only for meaning search, because the model is mostly English.

*"Why not open source?"*
> I want it to make money, and I'd rather be upfront about that than pretend. That's why I put the network behavior in writing and suggest Little Snitch.

*"Does this record my screen like Rewind?"*
> No. It indexes files in the folders you choose, screenshots you take, and what you copy. It never records your screen.

*"⌥Space conflicts with Alfred/Raycast."*
> Change it in Settings > General.

*"My screenshots aren't showing up."*
> Screenshot search is Pro, which is on for your first 14 days. If the trial ended, they're hidden, not deleted, and come back when you activate.

## 5. Before you post: your checklist

- Confirm the Cloudflare short and film are the same as the local 22.8 s short and 57.6 s master.
- Edit the sentence about notarizing when sales cover the $99. Don't promise a date.
- Fill the Nov 2 bracket with a real result, or skip that post.
- Read each subreddit's sidebar for karma limits and flair.
- Be online for the first 3 hours after each post and answer every comment.

## 6. Hacker News and Product Hunt

### Show HN

**Title:** Show HN: Recall, local semantic search for files, screenshots and clipboard on Mac

**URL:** https://raegent.com/recall

**First comment (post it yourself right after submitting):**

> I'm the developer. I kept losing screenshots, copied links and PDFs because I never remember filenames, only what the thing was about. Recall is a menu-bar app: ⌥Space opens a panel and you type something vague.
>
> How it works: it matches keywords and meaning together, with a small model that ships inside the app and runs on the CPU. A query takes about 5 to 7 ms on my Mac, and the index for ~1,400 items is about 90 MB. I'm keeping the internals to myself for now, but happy to talk about results.
>
> One result I liked: on ~280 of my screenshots, "pricing table" returns one that only says "Plans & Billing $29/mo" first.
>
> Things people will ask:
> - Closed source. Nothing is uploaded, and the only network use is the trial/license check (anonymous device ID, and your key once at activation, which my server checks with Dodo Payments and stores only as a hash) and update checks, which are off by default. Please verify with Little Snitch or LuLu.
> - Not notarized, because I haven't paid for the Apple developer account. On macOS 15+: open it, click Done, then System Settings > Privacy & Security > Open Anyway.
> - Apple Silicon only, macOS 14+, English only.
> - Free searches files and 7 days of clipboard. Every install gets 14 days of Pro automatically, no signup. Pro is $19 once (early bird, then $29), 3 Macs.
>
> I'd like to hear where the search gets it wrong.

Notes: HN dislikes marketing wording, so keep the title as is. Don't ask anyone to upvote it, and don't share the HN link asking for votes. Best time: Sun, 18:00 IST. No video; HN doesn't host any.

### Product Hunt

**Name:** Recall

**Tagline (max 60):** Search your whole Mac by what's in things, on-device

**Description (max 260):** Find files, screenshots and clipboard history by meaning, from one hotkey. Everything runs on your Mac and nothing is uploaded. No account. Every install gets a 14-day Pro trial, no signup or card. Apple Silicon, macOS 14+.

**Topics:** Mac, Productivity, Privacy

**Gallery:** the poster image first, then the 22.8 s short, then 2 or 3 screenshots of the panel.

**Maker comment:**

> Hi, I'm Rishabh, I made Recall. I never remember filenames, only what a screenshot, PDF or copied link was about. So I built a search that works from that. Press ⌥Space, type something vague, and it searches files, screenshots (it reads the text in them) and clipboard together.
>
> It runs on the Mac: keyword search plus a small on-device model for meaning. No account, nothing uploaded. Update checks are off until you turn them on.
>
> Honest bits: it isn't notarized yet, so macOS warns on first open (on macOS 15+: Done, then System Settings > Privacy & Security > Open Anyway). It's closed source, Apple Silicon only, English only. Free covers files and 7 days of clipboard, and every install gets 14 days of Pro. Pro is $19 once (early bird, then $29).
>
> Tell me what you searched for first and whether it found it.

Notes: schedule the listing ahead (it goes live at 12:01am Pacific, 12:31 IST). Post the maker comment as soon as it goes live. Don't ask for upvotes, and don't send the link to friends asking them to vote, since Product Hunt discounts it.
