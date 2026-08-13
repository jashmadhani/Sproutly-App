# Sproutly — App Store build

Private launch repo for **Sproutly**, a gentle, offline child-development milestone tracker.

The public repo ([jashmadhani/Sproutly](https://github.com/jashmadhani/Sproutly)) holds the
original `.swiftpm` Swift Playgrounds app package and stays as the archive/portfolio version.
This repo is the real Xcode project that ships to the App Store.

## Setup

The `.xcodeproj` is **generated** and is not committed. After cloning:

```sh
brew install xcodegen
xcodegen generate
open Sproutly.xcodeproj
```

Re-run `xcodegen generate` any time `project.yml` changes or files are added.

> **Important:** because the project is generated, do not configure capabilities, build
> settings, or scheme options through the Xcode GUI — those edits live in `Sproutly.xcodeproj`
> and are destroyed on the next `xcodegen generate`. Put them in `project.yml` instead.

## Layout

```
project.yml              project definition (single source of truth)
Sproutly/                app target
  MyApp.swift            @main entry + shared ModelContainer
  Models/                ChildProfile, Milestone, SwiftData schema + migration plan
  Views/                 screens
  Components/            reusable UI
  Managers/              DevelopmentObserver (rule-based domain scoring)
  ViewModels/            DashboardViewModel
  Resources/             Assets.xcassets, PrivacyInfo.xcprivacy
SproutlyTests/           unit tests
```

## Configuration

| | |
|---|---|
| Bundle ID | `com.jashmadhani.Sproutly` (identical to the `.swiftpm` — same ASC record, same on-device container) |
| Team | `FDYHXN3XSH` |
| Deployment target | iOS 17.0 |
| Devices | iPhone only, portrait only |
| Category | Lifestyle |
| Swift | 6.0 |

## Privacy

Sproutly makes no network calls, has no accounts, and collects nothing. `PrivacyInfo.xcprivacy`
declares no tracking, no collected data types, and a single accessed-API reason (`CA92.1`) for
`UserDefaults`. App Privacy on App Store Connect should read **Data Not Collected**.

If a future feature adds photo access, add `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` to
`project.yml` — a missing usage string is a launch-time crash and a review rejection.
