# ChiffCore ![Current version](https://img.shields.io/github/v/tag/chiff-app/chiff-ios-core?sort=semver) ![Twitter Follow](https://img.shields.io/twitter/follow/Chiff_App?style=social)

![Chiff logo](https://chiff.app/assets/images/logo.svg)

Chiff is a tool that allows you to log into any website with your phone. Passwords are stored on your phone and whenever you want to log in, you'll receive a push message to retrieve it.  
You can pair the app with multiple clients (browser extension or shell).

### Motivation
Passwords suck. You can use a password manager, but most password manager rely on a master password, which has both security and usability disadvantages. We wanted to created a system where you don't need a password at all and can log into any website the way you unlock your phone. We think the real way forward is [WebAuthn](https://www.w3.org/TR/webauthn/), but we need something else until the time that every website in the world supports that.

The idea behind Chiff is that it works in the same way for both *WebAuthn* and passwords. You simply authorize a request on your phone and either signs a challenge or sends back a password, depending on what the website wants. This way, we can already start using the new way of logging in, until the world catches up. 

Chiff also supports TOTP and HOTP codes, so you don't need another app for that.

### Security model
All sensitive data is stored encrypted on your phone. When needed, it is decrypted (by authenticating to your phone with biometrics) and sent to the browser/cli, where it is filled in the website. An end-to-end encrypted channel is established between browser/cli by scanning a QR-code. This means confidentiality is ensured, even though the server (mainly serving as message broker and backup storage) is modelled as an untrusted entity. In other words, the fact that you have the code of this app and the code of the [browser extension]((https://github.com/chiff-app/chiff-browser)) / [CLI](https://github.com/chiff-app/chiff-cli) should provide sufficient information to see that *you don't need to trust us*.
### Related projects
This is the repository for the *iOS app core*.  It is an SPM package that contains the core functionality of Chiff. It is used in [chiff-ios](https://github.com/chiff-app/chiff-ios).

For the *iOS app*, please see [chiff-ios](https://github.com/chiff-app/chiff-ios).  
For the *CLI*, please see [chiff-cli](https://github.com/chiff-app/chiff-cli).  
For the *Android app*, please see [chiff-android](https://github.com/chiff-app/chiff-android) (_Coming soon_).  
For the *Browser extension*, please see [chiff-browser](https://github.com/chiff-app/chiff-browser) (_Coming soon_).  

### Usage
To add this paclage as dependency, select File > Swift Packages > Add Package Dependency in Xcode, enter the repository URL: https://github.com/chiff-app/chiff-ios-core.git and import ChiffCore.

To use the package, add:

```swift
import ChiffCore
```

## License
All rights reserved. 
