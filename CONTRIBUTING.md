# Contributing to EST

Thank you for helping improve EST. Bug reports, accessibility fixes, copy
edits, tests, and focused code changes are welcome.

## Development setup

You need Xcode with an iOS 17 SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
2.30 or newer. XcodeGen is the source of truth for the project:

```sh
xcodegen generate
xcodebuild -project EST.xcodeproj -scheme EST \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Run the unit tests from Xcode or with an available iOS Simulator. The
`ESTUITests` target also contains the marketing screenshot test and requires a
bootable simulator.

Do not hand-edit `EST.xcodeproj`. Add or remove source files in the filesystem
and `project.yml`, then regenerate the project. Keep set-validation logic in
`Card` and table behavior in `GameEngine`.

## Pull requests

Keep changes focused and explain the user-visible effect. Include the commands
you ran and call out anything that could not be tested locally. New gameplay
rules should include unit coverage, and changes to telemetry must update the
privacy documentation and its visible Settings copy.
