# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.3.0] - 2020-04-03

### Added

- Team sessions are now included in the backup (does not work for existing team sessions).
- Functionality to convert an account into a shared (team) account. Accessible only by team admins.
- Search in accounts.
- Filtering accounts based on type.
- Sorting accounts based on most used / last used / alphabetically.
- Support for BulkLogin requests (log in at multiple tabs at once).
- Support BulkAdd requests (for import multiple accounts at once).
- Add a CHANGELOG.
- Add app version to pairing response to determine feature support.

### Changed

- Refactor to PromiseKit for async operations.

### Fixed

- Fix bug where WebAuthn wasn't properly deleted.
- Fix bug where adding an URL to an existing account did not log the user in.
- Fix bug where shared accounts were not queried when using the CredentialProvider.
