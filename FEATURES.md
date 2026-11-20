# Features

<!-- slaite:rules v10 -->
> **For AI agents:** this file is the project's feature backlog. People edit it in the Slaite app and agents edit it directly, so keep to the format below or the app can't read it. Slaite maintains this section and replaces it automatically when the format changes, so don't edit it.

**Structure**

- Each `##` heading is a group. There are exactly four: `Now`, `Next`, `Later` and `Done`.
- **The group headings are fixed.** Never rename, reword, reorder, merge or delete a `##` heading, and never add a new one (e.g. `Bugs`, `Sprint 2` or `Now (urgent)`). The app relies on these exact names, and `Done` in particular drives each feature's status.
- To add work, put new `###` features inside one of these groups. Choose the closest match (`Later` if unsure) rather than creating a group.
- Each `###` heading is a feature. Directly under the heading comes its metadata comment, then an optional description, then its tasks.
- Tasks are one-line checkboxes: `- [ ]` is open, `- [x]` is done.

**Metadata comment** (the line under each feature heading)

`<!-- id: f-k3x9q2 · status: todo · priority: high · due: 2026-12-01 · tags: Feature, Bug -->`

- `id`: unique. Use `f-` followed by 6 random lowercase letters or digits. Never change an existing id.
- `status`: `todo`, `in-progress`, `review` or `done`. The app manages this, so leave it alone on existing features and use `todo` for new ones.
- `priority` (optional): `urgent`, `high`, `medium` or `low`. Leave it out if unsure. Only change an existing priority when asked.
- `due` (optional): a deadline as `YYYY-MM-DD`. Only set or change it when asked, or when the request names a date.
- `tags` (optional): comma-separated, chosen only from this project's tags: `Feature`, `Bug`, `Improvement`, `Server`, `Design`, `API`, `Integration`, `Domain`, `Marketing`. Never invent other tags. Only change tags on existing features when asked.
- Keep the fields in that order, separated by ` · `.

**Deadlines**

- Whenever you start work or are asked what to do next, scan every feature's `due` date first.
- Call out anything overdue or due within 7 days before anything else, soonest first, then by priority.
- If you're working on something else while a feature is overdue, mention the overdue feature in your summary.

**When you work on a feature**

- Tick each task (`- [ ]` to `- [x]`) as soon as it's complete.
- If you find more work the feature needs, add it as a new `- [ ]` task under that feature.
- Don't edit other features unless you're asked to.
- Don't move features between groups. People do that in the app.
- A description may include screenshots as markdown images, e.g. `![screenshot](.features/assets/…)` (paths are relative to the project root; the folder can differ per project). Open them with your file-reading tool, since they often show the bug or design. Keep these lines when you edit the description.

**When you add a feature** (when asked, or to record follow-up work)

Add it to the right group (`Later` for follow-ups unless told otherwise) and fill in the metadata from what you know:

- `priority`: set it when the request says how important it is (e.g. "ASAP" or "blocking" is `urgent`, "nice to have" is `low`). Otherwise leave it out.
- `due`: set it when the request names a date or deadline, converted to `YYYY-MM-DD`.
- `tags`: add the ones that fit from `Feature`, `Bug`, `Improvement`, `Server`, `Design`, `API`, `Integration`, `Domain`, `Marketing` (e.g. `Bug` for something broken).

Shape it like this:

```markdown
### Short, specific feature title
<!-- id: f-7mq2zc · status: todo · priority: medium · tags: Feature -->

One or two sentences on what it is and why it's needed.

- [ ] First task
- [ ] Second task
```
<!-- /slaite:rules -->

## Now

### Ship 1.0.0
<!-- id: f-k19fb2 · status: todo · priority: high -->

Get the first signed, notarised build out through the release pipeline. Odo's Sparkle key and the `SPARKLE_PRIVATE_KEY`, `APPLE_TEAM_ID` and `MACOS_SIGNING_IDENTITY` secrets are already set, and `bymayo/odo-releases` exists.

- [ ] Set `MACOS_CERTIFICATE_P12` (export the Developer ID cert that expires Jan 2031, base64)
- [ ] Set `MACOS_CERTIFICATE_PASSWORD`
- [ ] Set `APPLE_ID` and `APPLE_APP_PASSWORD`
- [ ] Set `RELEASES_REPO_TOKEN` (fine-grained, contents write on `bymayo/odo-releases` only)
- [ ] Check all eight with `gh secret list -R bymayo/odo`
- [ ] Push `main` and confirm Release Health passes
- [ ] `make release VERSION=1.0.0` and watch the workflow
- [ ] Verify the DMG: `spctl -a -vvv -t install` says Notarized Developer ID
- [ ] Install 1.0.0 from the DMG on a clean account and connect Strava

### Prove Sparkle updates end to end
<!-- id: f-bzjgy9 · status: todo · priority: high -->

A release only proves the first install. Ship a small 1.0.1 and check an installed 1.0.0 finds it, shows the release notes and installs it.

- [ ] Release 1.0.1 with a changelog line
- [ ] Settings → Check for Updates on 1.0.0 offers 1.0.1 with the notes
- [ ] Update installs and relaunches without a Gatekeeper prompt
- [ ] Automatic background check picks it up on a second Mac or account

## Next

### Incremental sync
<!-- id: f-dcskmv · status: todo · priority: medium -->

Every sync re-downloads the whole current year, a page per 200 activities. Fetch only activities since the last sync instead, with an occasional full refresh to catch edits and deletions, so syncs are faster and use less of Strava's rate limit.

- [ ] Fetch with `after=` the newest cached activity's start time
- [ ] Full re-fetch of the current year once a day, and from Sync now
- [ ] Keep the rate-limit pause and progress status working with both

### Tests for the logic that matters
<!-- id: f-8zkyfr · status: todo · priority: medium -->

There's no test target. The parts most likely to break quietly are pure functions that are easy to test.

- [ ] Add a test target to `Package.swift`
- [ ] `RateLimit` header parsing and reset times
- [ ] `includes` with type/tag filters, hidden sports and the All tab
- [ ] Pace, forecast and streak maths across New Year and leap years
- [ ] Cache loading across cache versions and empty years
- [ ] Run tests in CI on pull requests

### Goal notifications
<!-- id: f-wlfhfh · status: todo · priority: medium -->

Odo only helps when you open it. A few well-timed notifications would make goals harder to forget, each one optional in Settings.

- [ ] Goal reached
- [ ] Weekly nudge when behind pace, with what it takes to catch up
- [ ] Week done / streak extended
- [ ] Settings toggles, off by default except Goal reached

### Sport tabs that don't overflow
<!-- id: f-j6q2bb · status: todo · priority: medium -->

The header shows one tab per visible sport, plus All. Someone with six or more sports runs out of width at 360pt.

- [ ] Collapse extra sports into a "More" menu, or scroll the tab row
- [ ] Keep the selected sport visible
- [ ] Same treatment for the tabs in Settings → Goals

## Later

### Remember a rate-limit pause across restarts
<!-- id: f-nghcsa · status: todo · priority: low -->

If Odo quits while paused for Strava's daily limit, it forgets and makes one more request on launch, which gets another 429.

- [ ] Persist the reset time with the cache
- [ ] Resume the pause on launch if it hasn't passed

### Year in review
<!-- id: f-ox9sub · status: todo · priority: low -->

A recap card at the end of the year and for past years: totals, best week and month, longest streak, biggest activity, and how it compares with the year before.

- [ ] Recap view, from the Year comparison tab
- [ ] Shown automatically in late December and January

### Monthly and custom-range goals
<!-- id: f-ihdh7l · status: todo · priority: low -->

Goals are yearly only. Shorter challenges, such as a 500 km month or a training block towards an event, would make Odo useful between January resolutions.

- [ ] Goals with a start and end date
- [ ] Pace, forecast and this-week maths for any range

### Global shortcut to open Odo
<!-- id: f-vl72b7 · status: todo · priority: low -->

Open and close the popover from the keyboard.

- [ ] Configurable shortcut in Settings
- [ ] Off by default

### Export activities as CSV
<!-- id: f-dsqezj · status: todo · priority: low -->

Odo already caches every activity. Let people get their yearly totals and activities out for a spreadsheet.

- [ ] Export the selected sport and year, filters applied
- [ ] Export everything

### Simpler Strava setup
<!-- id: f-mv40o7 · status: todo · priority: low -->

Connecting means creating your own Strava API app and pasting a client ID and secret. That's fine for developers but a wall for anyone else. Strava limits how many athletes a shared app can connect, so this needs their approval first.

- [ ] Apply to Strava for a higher athlete limit
- [ ] Shared app credentials with PKCE or a tiny token-exchange service
- [ ] Keep "use your own API app" as an advanced option

### Desktop and Notification Centre widgets
<!-- id: f-oqldsk · status: todo · priority: low -->

Goal progress at a glance without opening the menu. Widgets need an app extension, which a Swift package can't build, so this means adding an Xcode project or a separate extension target.

- [ ] Decide how to build an extension alongside the package
- [ ] Small widget: one goal's progress and pace
- [ ] Medium widget: this week

### Tidy signing certificates
<!-- id: f-dv1db5 · status: todo · priority: low -->

The login Keychain has two "Developer ID Application: Jason Mayo" certificates, which is why `.env.local` signs by hash. The older one expires in Feb 2027.

- [ ] Check Cargo doesn't still sign with the Feb 2027 certificate
- [ ] Remove it, then sign by name in `.env.local`

## Done
