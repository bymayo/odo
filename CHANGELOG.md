# Changelog

Notes for each release. The section matching the version being tagged is used
verbatim as the GitHub release body, and converted to HTML for the update panel
Sparkle shows in the app — so write it for the person receiving the update.

Format: `## <version>` followed by bullets. `**Bold**` and `` `code` `` work.

## 1.0.3

- The ODO name in the popover and Settings now matches the logo on odo.bymayo.co.uk

## 1.0.2

- A step-by-step guide to connecting Strava when you first open Odo, with a link to Strava's API settings and a button that copies the callback domain

## 1.0.1

- Turn each goal, and the This week card, on or off per sport. Switching one off keeps its number for later
- Clearer goal editing: the number sits in an input box, and "Suggest a goal" is a proper button with a tidier set of suggestions
- A bigger Settings window with larger controls and its pages listed down the left: General, Menu bar, Goals, Sports, Fitness, Notifications, Account, Updates and a new About page
- Lime progress bars, chart lines and ahead-of-pace figures in light mode too, in deeper shades so they stay readable

## 1.0.0

- First release of **Odo**: your yearly goals in the menu bar, from your Strava activities.
- New look: odo's lime, black and grey and the Switzer typeface throughout the app and its icon
- Goal cards with pace, how you compare with this time last year, and what it takes each week to get back on pace. One goal shows in full and the rest fold to a single line; click one to open it.
- This week card with a streak of weeks hitting your weekly pace.
- Year comparison graph with a podium for your best years, hover to scrub, click to lock.
- Smart goals that suggest targets from your recent years. Each goal has its own ✨ button, so picking one only changes that goal.
- Filter by activity type and tags like Commute and Race.
- An **All** tab that adds up every sport, with its own goals and a this-week card showing each sport against its own weekly pace. Each sport's filters still apply, and it can be shown in the menu bar.
- Syncing shows which year it's fetching and how many activities so far. If Strava's API limit is reached, Odo says when and carries on by itself once it resets.
- The window fits its content, and never runs off the bottom of a smaller screen.
- A new icon: a running track with your lap drawn round it, in the menu bar and the app.
- Opening Odo from the menu bar starts fresh: Goals, on the sport the menu bar is set to, with filters closed and graphs unlocked.
- When you're behind, each goal shows what you need each week to get on pace in one clear line; hover it for the detail.
- A **Fitness** tab for every sport and All: fitness, fatigue and form from the last six weeks back to your first activity, so you can see where training built you up and where it dropped off. Load comes from heart rate where your activities have it (set your max and resting heart rate in Settings), otherwise from Strava's Relative Effort or time. Odo re-syncs your history once to pick up heart rate.
- Kudos: a well done notification when a new activity syncs, with its distance, time and climbing, how far it takes your goal, and a bigger cheer for the one that reaches it.
- Notifications: a summary at the start of each week, month and year comparing it with the one before, a midweek reminder when you've fallen behind pace, and a note when you're back on it. They follow the menu bar's sport and metric, and each can be turned off in Settings.
- When the catch-up needed is more than you've been doing, goals also show a doable target, worked out from how you're going this year.
- Each goal's bar now shows where you'll finish at this rate (a fainter green) and the doable target (a gold tick), with a key under the numbers.
- Switching tabs and sports is quick, even with thousands of activities.
- Updates install automatically.
