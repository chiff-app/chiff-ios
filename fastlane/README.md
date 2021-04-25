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
or alternatively using `brew install fastlane`

# Available Actions
## iOS
### ios test
```
fastlane ios test
```
Run tests
### ios upload_symbols
```
fastlane ios upload_symbols
```
Upload dSYMs to Crashlytics
### ios build
```
fastlane ios build
```
Build app
### ios start_minor_release
```
fastlane ios start_minor_release
```
Start minor release
### ios start_patch_release
```
fastlane ios start_patch_release
```
Start patch version
### ios start_major_release
```
fastlane ios start_major_release
```
Start major version
### ios start_hotfix
```
fastlane ios start_hotfix
```
Start hotfix version
### ios beta_release
```
fastlane ios beta_release
```
Beta release
### ios release
```
fastlane ios release
```
Submit Chiff to the App Store

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
