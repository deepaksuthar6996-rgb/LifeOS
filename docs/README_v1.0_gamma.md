# Ascend LifeOS v1.0: Dynamic Categories, AI Ingestion & DB Schema v6

This documentation covers the data modeling and ingestion features introduced in release Gamma v1.0.

## 🧭 Objective

To build an extensible categorization architecture and support loading/restoring goals and milestones via structured AI-generated JSON outputs.

## 🛠️ Key Architectural Updates

- **Database Upgrade (Schema v6)**: Introduced the `categories` table. It seeds four default categories (Career, Health, Skill Development, Personal) and supports user-defined custom categories.
- **Dynamic Category Management**: The UI was updated to allow users to add new categories on the fly, with color palettes dynamically resolving based on string hashes.
- **Structured JSON Ingestion (Backup & Restore)**: Standardized the JSON backup schema to support AI-ingested outputs. This lets users upload goals, milestones, and tasks written or compiled by AI models directly into their local sqlite database.
- **Automatic Categories Migration**: Runs a migration parsing existing goals to extract unique category strings, populating them as custom categories during schema upgrade.
