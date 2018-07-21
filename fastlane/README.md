fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew cask install fastlane`

# Available Actions
## iOS
### ios tests
```
fastlane ios tests
```
Run all tests
### ios build_keyn_beta
```
fastlane ios build_keyn_beta
```
Build app
### ios release_minor_version
```
fastlane ios release_minor_version
```
Release minor version
### ios release_patch_version
```
fastlane ios release_patch_version
```
Release patch version
### ios release_major_version
```
fastlane ios release_major_version
```
Release major version

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
