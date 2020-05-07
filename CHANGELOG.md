# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.4.3] - 2020-05-06

### Fixed

- Fixed a bug where the password wasn't updated correctly

## [3.4.2] - 2020-04-21

### Fixed

- Fixed bug where app crashed when adding an account to a team.

## [3.4.1] - 2020-04-18

### Fixed

- Fixed push messages for iOS13.

## [3.4.0] - 2020-04-17

### Added

- Added syncing between multiple devies that have the same seed.
- Added compression to backup data
- Added encrypted notes to an account.

### Changed

- Sorting preference is now persistent.
- Clocks are now synced with NTP server.

### Fixed

- Fixed bug where useraccounts where not created when restoring a team.
- Update the team logo more efficiently

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
