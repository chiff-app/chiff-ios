# Keyn swift app
iOS App

## Install
```
sudo gem install cocoapods
pod install
build in xcode
```

# Tests
The code has a few tests but it is far from complete. Mostly because we use a lot of singletons.
E.g. Session is not testable because we are doing network requests and use the keychain and we cannot inject dependencies in current architecture.

We *do* test parts of:
- Core/Crypto.swift
- Core/NotificationProcessor.swift
- Core/PasswordGenerator.swift
- Core/PasswordValidator.swift
