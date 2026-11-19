# Grape — Family Coordination App

Grape is a family coordination iOS app that helps households manage tasks, schedules, communication, family membership, and a shared wallet in one place.

## Overview

Grape combines everyday family workflows into a single, clean interface:
- Daily task assignment and completion tracking
- Family schedule and event planning
- Shared family group chat
- Family wallet for income, spending, cash flow, and savings goals

The goal is to reduce miscommunication and help family members stay aligned.

## Problem Statement

Families commonly face:
- Unclear task ownership
- Missed schedules and events
- Fragmented communication
- Disorganized shared spending and saving plans

Grape solves this with a centralized and intuitive coordination system.

## Features

### Authentication & Onboarding
- Login and registration through Firebase Auth when Firebase packages are available
- Quick demo sign-in profiles for local testing
- Create or join a family using a shareable Family ID

### Home Dashboard
- Overview of today's progress and schedule
- Quick snapshot of family members
- Fast entry points to key modules

### Tasks Management
- Create tasks with due date/time
- Assign tasks to family members
- Toggle completion with checklist interaction

### Schedule / Calendar
- Daily schedule view
- Add events with date and time
- Timeline-style presentation

### Communication
- Family group chat (text-only)
- Shared updates between family members
- No private chat, no image upload

### Family Wallet
- Record income and expense transactions
- Monthly net cash-flow summary with income and spending tiles
- Six-month cash-flow trend chart
- Category-based spending mix
- Savings goal card with target amount and target date
- Goal progress uses saved-so-far plus this month's positive cash flow
- Custom target-date selector styled to match the app palette

### Family Management
- Create or join a family via Family ID
- Role-based member management (Owner/Admin/Parent/Child)
- Join request approval/rejection flow
- Cloud sync status display

## Tech Stack

- Swift
- SwiftUI
- Firebase Auth
- Firebase Firestore
- Local JSON persistence
- Xcode project-based iOS app

## Data & Backend Status

Current state:
- Local JSON is used as the on-device store and offline cache.
- Firebase Auth powers account login/registration when configured.
- Firestore sync is implemented for family-scoped state, including members, join requests, tasks, schedules, group messages, wallet transactions, and savings goals.

Planned:
- Harden Firestore security rules and sync conflict handling for production use.
- Add broader automated test coverage for state sync and finance calculations.

## Demo Accounts

Demo credentials are intentionally omitted from this public repository.

## Project Structure

```text
Grape/
  Components/      # Reusable UI components
  Models/          # Domain models and mock seed data
  Services/        # Local JSON persistence and Firebase sync
  ViewModels/      # App-level state and business logic
  Views/           # Screens (Auth, Home, Tasks, Schedule, Chat, Wallet)
  Assets.xcassets/ # App and in-app image assets
```

## Getting Started

1. Clone the repository.
2. Open `Grape.xcodeproj` in Xcode.
3. Select an iOS simulator/device.
4. Build and run the `Grape` target.

## CI

GitHub Actions includes an iOS build workflow:
- File: `.github/workflows/ios-build.yml`
- Trigger: `push`/`pull_request` on `main`
- Purpose: compile-level verification with `xcodebuild`

## Commit Convention

Use this unified format:

```text
<type>(<scope>): <summary>
```

Examples:
- `feat(home): redesign dashboard card spacing`
- `fix(auth): resolve registration username binding`
- `refactor(state): split family role checks`
- `ci(build): stabilize GitHub Actions xcodebuild job`

Allowed `type` values:
- `feat` (new feature)
- `fix` (bug fix)
- `refactor` (code cleanup without behavior change)
- `style` (UI/style only)
- `docs` (documentation)
- `test` (tests)
- `chore` (tooling/dependency/non-feature work)
- `ci` (workflow/pipeline changes)

Rules:
- Use imperative summary, present tense.
- Keep summary within about 50 characters when possible.
- One commit should focus on one concern.
- Prefer English commit messages for consistency.

Template file:
- `commit-template.txt`

## License

This project is licensed under the MIT License.
