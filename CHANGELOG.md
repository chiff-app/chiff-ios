# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.10.0] - 2021-04-15

### Added

- Added support for WebAuthn attestation
- Added button with instructions on how to enable AutoFill.
- Generate password when creating an account.
- Added functionality to create an account from AutoFill provider.
- Added functionality to share Chiff with a friend.
- Added functionality to periodically ask users for an App Store review.
- Added possibility to directly add OTP when creating a new account.

### Changed

- Extract core into library.
- Use SPM for dependencies.
- Changed the color of the copy label.

### Fixed

- Fixed bug with background color on password popup.
- Fixed a bug where accounts written by Android with OTP-urls with spaces in the issuer name were ignored.
- Fixed a bug where accounts with PPDs with default attributes were not correctly parsed.
- Fixed a bug where the lock screen didn't show after authorizing a request with an OTP-code.


## [3.9.0] - 2021-01-15

### Added

- Added support for Opera browser.
- Added SwiftLint config file.
- Added LICENSE.
- Added documentation.
- Added support for P384 and P521 curves for WebAuthn
- Keychain versioning

### Changed

- Moved to SPM from CocoaPods.
- Update README text.
- Code refactoring to comply with SwiftLint.
- Create seperate KeychainService for shared account TOTP & notes.

### Removed

- Removed unused code.

### Fixed

- Fixed team background color
- Fixed issue where team user couldn't be deleted when creation was cancelled

## [3.8.2] - 2020-08-25

### Added

- Add feedback about progress for CSV import request.

### Changed

- Removed the 'synced' attribute in Account.

### Fixed

- Fix issue where CSV import did not work properly

## [3.8.1] - 2020-09-21

### Fixed

- Fix issue with creating organization.
- Fix issue where session names were switched.

## [3.8.0] - 2020-08-11

### Added

- Added support for Brave browser.

### Changed

- Change the way teams are created.

### Fixed

- Fixed malformatted linebreak.
- Fixed issue where sessions where deleted when migrated from an older version.
- Fixed issue where app crasshed when URL was malformatted.
- Fixed issue where account wasn't updated when app was open for a long time.

## [3.7.0] - 2020-07-28

### Added

- Add icon when personal account is shadowed by a shared account.
- Added functionality to create a team.

### Changed

- Prevent creation of session accounts with same ID.
- Share admin status with extension.
- Updated terms of use.

### Fixed

- Fixed bug where notifications did not arrive when app was closed.
- Fixed bug where previous requests remained visible on screen.

## [3.6.2] - 2020-06-26

### Added

- Added 'deny' button for push notifications

## [3.6.1] - 2020-06-25

### Added

- Added support for CLI session.

### Changed

- Sort sessions by date

### Fixed

- Fixed bug where ManualOTP controller crashed when entering non-base32 characters.
- Fixed bug where seed was still loaded if restoring failed.
- Fixed bug where button still animated loading after cancelling.
- Fixed bug wher yellow highlights disappeared in texts.

## [3.6.0] - 2020-06-18

### Changed

- The name!
- Custom passwords now have a maximum length of 100 characters.

### Fixed

- Fixed bug wher feedback wasn't sent.
- Fixed bug where OTP code didn't show after authorizing request.

## [3.5.0] - 2020-05-27

### Added

- Added functionality to remove an account from the team (team admins only).
- Added TOTP to team accounts.
- Importing accounts from CSV now also import notes.

### Changed

- Team members now try to fetch PPDs from the organisation-repository first.
- Removed 'News from Keyn' push messages and changed to poll.

### Fixed

- Throw errors when incosistency in PPD is found.
- Update app version in sessions after updating app.
- Fix bug where showing the password when editing showed the old password.

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
