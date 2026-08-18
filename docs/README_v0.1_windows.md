# Ascend LifeOS v0.1: Desktop Capacity Engine

This documentation details the initial architecture of the desktop beta of Ascend LifeOS (v0.1).

## 🧭 Objective

To build a high-performance, offline-first personal operating system tailored for desktop systems. The primary architectural goal was to ensure total privacy by using local database systems and supporting raw export/import features.

## 🛠️ Key Engine Architecture

- **SQLite Workspace Backend**: Setup SQLite database locally using FFI bindings (`sqflite_common_ffi`) to support native execution on Windows, Linux, and macOS platforms.
- **Sleep Capacity calculations**: Uses a standard sleep model (e.g. 22:00 -> 04:00) to calculate the waking hours capacity in a day (1440 minutes minus sleep minutes = focus capacity).
- **Workspace Backup Engine**: Local JSON file exports and imports to allow users to completely backup, restore, or migrate their data offline without an internet connection.
- **Task & Milestone Layouts**: Simple relational database mappings that link parent Goals to milestones and task items.
