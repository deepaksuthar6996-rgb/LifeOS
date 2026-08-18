# Ascend LifeOS v1.5: Habits Protocol, Exact Alarms & Persistence

This documentation covers the core habits protocol, alarm scheduler, and theme persistence updates in release Gamma v1.5.

## 🧭 Objective

To build an exact alert system, support recurring task tracking without losing historical completion analytics, and persist theme and category colors in a local key-value settings table.

## 🛠️ Feature Details

### 1. Habits Protocol (DB Schema v7 Upgrade)
- **Schema Modification**: Added `isRecurring` (bool/int) and `recurringDays` (comma-separated weekday list) columns to the `tasks` table. Added the `task_completions` table to track historical completes.
- **Historical completion logging**: Completing a task logs a record in `task_completions(id, task_id, completed_date, focus_minutes)`. Unchecking a task deletes its entry for the current day.
- **Midnight Auto-Rollover**: At midnight, all recurring tasks have their `isDone` flag reset to 0, resetting their checked state on the dashboard so they can be completed again today. Streak analytics are calculated from `task_completions` records to maintain integrity.
- **Weekday filtering**: Incomplete recurring tasks are only loaded onto the active schedule/dashboard if today's weekday matches their `recurringDays` list.

### 2. Native Notifications & Alarm Engine
- **Android Manifest permissions**: Added `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, and `POST_NOTIFICATIONS` to support precise alarm triggers on Android.
- **Scheduling**: Triggers exact local notifications:
  - **Exact Alert**: Fired at the event start time.
  - **5-Minute Pre-Alert**: Fired 5 minutes before the event start.
- **Rescheduling**: Whenever a calendar event is added, updated, or deleted (or when the app initializes), the exact alarm schedule is rebuilt for the next 7 days.

### 3. Theme & Color Customization Persistence
- **Settings Table**: Introduced `settings` key-value table to persist configurations.
- **Boot Pre-loading**: Loaded from SQLite during startup (`main()`) to prevent UI flickering.
- **Custom Accent register**: Users can personalize the main theme mode (Dark, Light, System) and override colors for specific categories. Tapping a category color circle in settings updates the database and applies overrides instantly.
