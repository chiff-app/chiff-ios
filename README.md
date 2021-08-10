# Chiff for iOS ![Current version](https://img.shields.io/github/v/tag/chiff-app/chiff-ios?sort=semver) ![Twitter Follow](https://img.shields.io/twitter/follow/Chiff_App?style=social)

![Chiff logo](https://chiff.app/assets/images/logo.svg)

Chiff is a tool that allows you to log into any website with your phone. Passwords are stored on your phone and whenever you want to log in, you'll receive a push message to retrieve it.  
You can pair the app with multiple clients (browser extension or shell).

### Motivation
Passwords suck. You can use a password manager, but most password manager rely on a master password, which has both security and usability disadvantages. We wanted to created a system where you don't need a password at all and can log into any website the way you unlock your phone. We think the real way forward is [WebAuthn](https://www.w3.org/TR/webauthn/), but we need something else until the time that every website in the world supports that.

The idea behind Chiff is that it works in the same way for both *WebAuthn* and passwords. You simply authorize a request on your phone and either signs a challenge or sends back a password, depending on what the website wants. This way, we can already start using the new way of logging in, until the world catches up. 

Chiff also supports TOTP and HOTP codes, so you don't need another app for that.

### Security model
#### Short version
All sensitive data is stored encrypted on your phone. When needed, it is decrypted (by authenticating to your phone with biometrics) and sent to the browser/cli, where it is filled in the website. An end-to-end encrypted channel is established between browser/cli by scanning a QR-code. This means confidentiality is ensured, even though the server (mainly serving as message broker and backup storage) is modelled as an untrusted entity. In other words, the fact that you have the code of this app and the code of the [browser extension]((https://github.com/chiff-app/chiff-browser)) / [CLI](https://github.com/chiff-app/chiff-cli) should provide sufficient information to see that *you don't need to trust us*.

#### Long version
TODO: Link to security whitepaper.

### Screenshots
TODO

### Related projects
This is the repository for the *iOS app*.  
For the *Android app*, please see [chiff-android](https://github.com/chiff-app/chiff-android).  
For the *Browser extension*, please see [chiff-browser](https://github.com/chiff-app/chiff-browser).  
For the *CLI*, please see [chiff-cli](https://github.com/chiff-app/chiff-cli).  
For the *Backend*, please see [chiff-backend](https://github.com/chiff-app/chiff-backend). 

## Installation
The easiest way is to install the version from the App Store:

[![Download on the app store](https://chiff.app/assets/images/app-store.svg)](https://apps.apple.com/app/id1361749715)

Or you can build it yourself and run it on your phone. See instructions below at *Building Chiff*.

## Using Chiff

### Pairing
After downloading the app and walking through the initialization steps, you can pair the app with a client, which can be the Chiff [browser extension](https://github.com/chiff-app/chiff-browser) and/or the Chiff [CLI](https://github.com/chiff-app/chiff-cli).

### Adding accounts
You can add accounts the following ways:

1. [Browser extension] You can add a new account to Chiff by logging in on a website as you'd normally do on your computer. If you have the Chiff browser extension installed, it will ask you if you want to add your account to Chiff. Just authorize the request to add the site on your phone with your fingerprint and you're good to go!
2. [Browser extension] You can import multiple accounts on the *Personal accounts* page, reachable through the browser extension menu. Here you can import a CSV file.
3. [Browser extension] You can add a new account manually from the browser extension menu.
4. [App] You can add a new account manually on the accounts tab in the app.
5. [CLI] With the CLI, using the command `chiff add`. See `chiff add --help` for more info.

### Logging in
To log in on your phone, you should set Chiff as a password provider. This allows iOS to retrieve passwords from Chiff after authorizing it. This can be done in 'Phone settings' -> 'Passwords' -> 'AutoFill'.

In the browser extension, Chiff will (usually) automatically ask you if you want to log in when focusing on a login form. If not, you can click the brower extension menu and pick 'Log in to *website*'.

### Changing password
To be more secure, you should change your password to randomly generated ones (if they aren't already). Click 'change password' in the browser extension menu when logged in to a website and follow to steps indicated by Chiff to change your password.

### Backup
When initializing Chiff, a 128-bit seed is randomly generated. Passwords and encryption keys are derived from this seed, which means that you can restore your data if you lose your phone. We present the seed in the form of a 12-word mnemonic, based on [BIP-0039 of Bitcoin](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki).
**Make sure you write this *paper backup* down and store it in safe place**:

* If you lose it, there is no way to retrieve your passwords.
* If someone else gets hold of it, he/she can retrieve all your passwords. 

## Building Chiff

### Prerequisites

To build this project, you need a *MacOS* machine with the latest version of Xcode.
Furthermore, the build process assumes that *Ruby* is present.
Install the ruby dependencies with 

```bash
bundle install
```

### Build with Xcode
Open `chiff.xcodeproj` with *XCode*. We use SPM for dependencies, so Xcode should automatically resolve those as soon as the project is opened.
Simply build by clicking the *build* button.

### Build with Fastlane
We also have fastlane scripts to build from commandline. To use these, you should first install Fastlane. This can be installed through various methods, but the easiest is to run `bundle` in the project folder to install via the *Gemfile*. Note that you also still need the *Xcode additional components*.

To build Chiff, run
```
bundle exec fastlane build
```

## License
All rights reserved. 
