# 🌌 Ascend LifeOS (Master Release: Gamma v1.5)

Welcome to **Ascend LifeOS**, an offline-first personal operating system designed to track, schedule, optimize, and elevate daily workflows, strategic goals, and routines. 

Ascend acts as a highly structured, local "second brain" that empowers engineers, creators, and professionals to organize their daily schedule and build long-term habits without leaving any data footprint online.

---

## 🧭 System Overview

Ascend LifeOS integrates goal management, milestones, local scheduling, habit logging, and capacity-based planning in a modern, glassmorphic visual wrapper.

```text
PROJECT ASCEND_LIFEOS/
├── app/           # Core Flutter Application
│   ├── assets/    # Brand resources (ASCEND_LOGO.png)
│   ├── android/   # Android platform native code & manifest
│   ├── ios/       # iOS platform native code
│   └── lib/       # Flutter application code
├── architecture/  # Architecture diagrams and specifications
├── assets/        # System assets and branding
├── docs/          # Versioned history and specs
│   ├── README_v0.1_windows.md   # Desktop Capacity Engine
│   ├── README_v1.0_alpha.md     # Mobile Layout & Touch Ergonomics
│   ├── README_v1.0_gamma.md     # AI JSON Ingestion & Schema v6
│   └── README_v1.5_gamma.md     # Habits Protocol, Local Alarms & Persistence (New)
└── README.md      # Master entry point (this file)
```

---

## 🚀 Release Version Evolution

Ascend LifeOS has evolved through distinct development phases, each documented in detail in our versioned history:

1. **v0.1 Desktop Beta**: [Desktop Capacity Engine](docs/README_v0.1_windows.md) - SQLite-backed task layout, sleep capacity models, offline data import/export.
2. **v1.0 Alpha**: [Mobile & Touch Layouts](docs/README_v1.0_alpha.md) - Screen scaling, touch targets, and visual card layouts.
3. **v1.0 Gamma**: [Dynamic Categories & AI Ingestion](docs/README_v1.0_gamma.md) - Dynamic category additions, AI-powered JSON data loading, and SQLite database migration schema v6.
4. **v1.5 Gamma (Current)**: [Habits Protocol & Exact Alarms](docs/README_v1.5_gamma.md) - Local alarms, theme persistence (SQLite key-value settings table), recurring task roll-overs, and unified completion stats in `task_completions`.

---

## 🛠️ Main Features in Gamma v1.5

- **Habits Protocol**: Adds support for repeating/recurring tasks. Completions are logged inside a separate historical database table (`task_completions`) so that midnight rollovers can reset task flags without losing streak metrics.
- **Native Notifications & Alarm Engine**: Integrates exact alarm notifications (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS`) to send alert triggers directly to the user (a 5-minute pre-alert warning and an exact event start notification).
- **Persistent Theme & Category Accents**: Persists dark/light/system theme configuration and customized category accent overrides directly to the local SQLite database settings table, resolving app boot flickering.
- **Developer Card**: Displays developer identity (Lead Architect: Deepak Suthar) with external launcher actions for ProtonMail, GitHub, and Instagram.

---

## 🚀 Getting Started

To run the application locally on your mobile device or emulator:

1. Clone or sync the repository.
2. Navigate to the `app/` folder.
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run the launcher icon builder:
   ```bash
   dart run flutter_launcher_icons
   ```
5. Launch the application:
   ```bash
   flutter run
   ```
