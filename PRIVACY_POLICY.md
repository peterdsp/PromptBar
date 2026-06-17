# Privacy Policy

Last Updated: 2026-06-13

## 1. Introduction

PromptBar is a generic macOS menubar **web-chat container**. It lets you wrap any
web URL you choose in a fast menubar popover. PromptBar does not provide chat
services itself, it only renders the websites you add inside `WKWebView`.

This policy describes what PromptBar handles and what is handled by the
third-party websites you choose to load.

## 2. Data Collection by PromptBar

PromptBar **does not collect, transmit, or store** any of the following:

* User accounts or identifiers
* Chat messages or page contents
* Usage analytics, telemetry, or tracking events
* IP addresses (beyond what `WKWebView` itself sends to the sites you load)
* Crash reports

The app **does not include** any analytics SDK, advertising SDK, telemetry
framework, or remote configuration service. (As of version 2.0, Firebase
Analytics and Firebase Remote Config have been removed entirely.)

## 3. Authentication and Accounts

PromptBar does not create user accounts. There is nothing to sign up for and
nothing to delete on our side.

If a website you add to PromptBar requires sign-in, that authentication happens
**inside the website itself**, hosted by the third party. PromptBar never sees,
stores, or transmits your credentials. To delete a third-party account, follow
the instructions on that third party's own site.

## 4. Local Storage

PromptBar stores the following on your Mac only, never transmitted anywhere:

* Your list of services (names, URLs, icons, colors), `UserDefaults`
* Your window-size preference, `UserDefaults`
* Your "always on top" preference, `UserDefaults`

Because PromptBar uses `WKWebView` with the default website data store, WebKit
may store cookies, local storage, IndexedDB, caches, and other website data
locally for the sites you visit. This is how those sites remember your sign-in
between launches.

You can wipe all WebKit local website data at any time via
**Menu → Clean Cookies & Cache**.

## 5. Updates

PromptBar checks for new versions by sending an anonymous HTTPS request to the
GitHub Releases API endpoint
`https://api.github.com/repos/peterdsp/PromptBar/releases/latest`. No identifying
data is included in this request beyond what GitHub itself receives from any
public HTTP client.

## 6. Third-Party Sites

When you add a URL to PromptBar, that site's privacy policy applies to anything
you do inside it. Common examples (this is a generic list, PromptBar does not
endorse, integrate with, or have a business relationship with any of them):
visit each provider's website for their own privacy policy.

## 7. Changes to This Policy

Significant changes will be communicated through the project repository.

## 8. Contact

For questions, open an issue on the
[GitHub repository](https://github.com/peterdsp/PromptBar) or contact the
project maintainer.
