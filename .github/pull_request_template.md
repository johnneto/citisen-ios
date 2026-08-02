## Summary

<!-- What does this PR change, and why? One or two sentences. -->

## Changes

<!-- Bullet the notable changes. Mention new files/services and anything reviewers should read first. -->

-
-

## Type of change

- [ ] Feature (`feat`)
- [ ] Bug fix (`fix`)
- [ ] Refactor (`refactor`)
- [ ] Chore / tooling (`chore`)
- [ ] Docs (`docs`)

## Screenshots / recordings

<!-- UI changes: before/after from the simulator. Delete this section if not applicable. -->

## Testing

<!-- How did you verify this? -->

- [ ] `xcodebuild test -project Citisen.xcodeproj -scheme Citisen -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` passes
- [ ] `swiftlint lint --strict` passes
- [ ] Ran on the simulator and exercised the affected screens

Manual steps:

1.

## API & cost impact

<!-- Delete if this PR does not touch the Gemini / Places pipeline. -->

- [ ] No change to the number of Gemini or Places calls per city/mode
- [ ] Field masks unchanged (or: the added fields and their SKU impact are noted below)
- [ ] Cache behaviour unchanged (TTLs, cache keys, migration)

Notes:

## Checklist

- [ ] Targets `develop` (not `main`)
- [ ] Commits follow Conventional Commits
- [ ] No secrets, API keys or `Secrets.xcconfig` committed
- [ ] New user-facing strings and permission copy reviewed
- [ ] ADR added or updated under `docs/ADRs/` if this changes an architectural decision

## Related issues

<!-- Closes #123 -->
