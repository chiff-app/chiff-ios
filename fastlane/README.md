fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

### ios upload_symbols

```sh
[bundle exec] fastlane ios upload_symbols
```

Upload dSYMs to Sentry

### ios finalize_release

```sh
[bundle exec] fastlane ios finalize_release
```

Finalize release

### ios build

```sh
[bundle exec] fastlane ios build
```

Build app

### ios create_sentry_release

```sh
[bundle exec] fastlane ios create_sentry_release
```

Create sentry release

### ios create_sentry_deployment

```sh
[bundle exec] fastlane ios create_sentry_deployment
```

Create sentry deployment

### ios start_minor_release

```sh
[bundle exec] fastlane ios start_minor_release
```

Start minor release

### ios start_patch_release

```sh
[bundle exec] fastlane ios start_patch_release
```

Start patch version

### ios start_major_release

```sh
[bundle exec] fastlane ios start_major_release
```

Start major version

### ios start_release

```sh
[bundle exec] fastlane ios start_release
```

Start release

### ios start_hotfix

```sh
[bundle exec] fastlane ios start_hotfix
```

Start hotfix version

### ios beta_release

```sh
[bundle exec] fastlane ios beta_release
```

Beta release

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit Chiff to the App Store

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
