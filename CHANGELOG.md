# Changelog

Notes for each release. The section matching the version being tagged is used
verbatim as the GitHub release body, and converted to HTML for the update panel
Sparkle shows in the app — so write it for the person receiving the update.

Format: `## <version>` followed by bullets. `**Bold**` and `` `code` `` work.

## 1.0.0

- First release of **Odo**: your yearly goals in the menu bar, from your Strava activities.
- Goal cards with pace, a finish-date forecast and what it takes each week to get back on pace.
- This week card with a streak of weeks hitting your weekly pace.
- Year comparison graph with a podium for your best years, hover to scrub, click to lock.
- Smart goals that suggest targets from your recent years.
- Filter by activity type and tags like Commute and Race.
- An **All** tab that adds up every sport, with its own goals and a this-week card showing each sport against its own weekly pace. Each sport's filters still apply, and it can be shown in the menu bar.
- Syncing shows which year it's fetching and how many activities so far. If Strava's API limit is reached, Odo says when and carries on by itself once it resets.
- The window fits its content, and never runs off the bottom of a smaller screen.
- A new icon: a running track with your lap drawn round it, in the menu bar and the app.
- Opening Odo from the menu bar shows the sport the menu bar is set to.
- When you're behind, each goal shows what you need each week to get on pace in one clear line; hover it for the detail.
- A **Fitness** tab for every sport and All: fitness, fatigue and form from the last six weeks back to your first activity, so you can see where training built you up and where it dropped off. Load comes from heart rate where your activities have it (set your max and resting heart rate in Settings), otherwise from Strava's Relative Effort or time. Odo re-syncs your history once to pick up heart rate.
- Updates install automatically.
