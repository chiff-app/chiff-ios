# Chiff for iOS
![Twitter Follow](https://img.shields.io/twitter/follow/Chiff_App?style=social)

Chiff is a tool that allows you to log into any website with your phone. Passwords are stored securely on your phone and whenever you want to log in, you'll receive a push message to retrieve it.  
You can pair the app with you browser or your shell.

This is the repository for the *iOS app*.  
For the *Android app*, please see [chiff-android](https://github.com/chiff-app/chiff-android).  
For the *Browser extension*, please see [chiff-browser](https://github.com/chiff-app/chiff-browser).  
For the *CLI*, please see [chiff-cli](https://github.com/chiff-app/chiff-cli).

## Prerequisites

To build this project, you need a *MacOS* machine with the latest version of Xcode.
Furthermore, the build process assumes that *Ruby* is present.

## Building Chiff

### Xcode
Open `chiff.xcodeproj` with *XCode*. We use SPM for dependencies, so Xcode should automatically resolve those as soon as the project is opened.
Simply build by clicking the  *build* button.

### Fastlane
We also have fastlane scripts to build from commandline. To use these, you should first install Fastlane. This can be installed through various methods, but the easiest is to run `bundle` in the project folder to install via the *Gemfile*.

To build Chiff, run
```
bundle exec fastlane build
```

## License
We are planning to make (parts of) Chiff available under an open source license in the future. Until then, all right reserved.
