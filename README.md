# MacCleaner

A native SwiftUI macOS storage manager inspired by the supplied dashboard concept.

## Architecture

- `App/Core/Models`: immutable domain models.
- `App/Core/Services`: scanning and cleanup boundaries, exposed through protocols.
- `App/MacCleaner/App`: composition root and observable application state.
- `App/MacCleaner/Features`: SwiftUI screens grouped by feature.
- `Tests/MacCleanerCoreTests`: unit tests for domain and safety rules.

Dependencies point inward: the UI depends on `MacCleanerCore`, while the core does
not import SwiftUI. Services are injected into the view model so behavior can be
tested without touching the real filesystem.

## Run

Open `Package.swift` in Xcode and run the `MacCleaner` scheme, or run:

```sh
swift run MacCleaner
```

Run the verification suite with:

```sh
swift test
```

## Safety model

- Scans are read-only.
- Cleanup is limited to top-level items inside `~/Library/Caches`.
- Large files are shown for review and are never preselected.
- Cleanup moves items to the macOS Trash instead of permanently deleting them.
- System folders and files outside the current user account are never modified.
