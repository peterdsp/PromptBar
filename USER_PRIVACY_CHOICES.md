# User Privacy Choices

PromptBar gives you full control over the local data the app keeps on your Mac.
This document explains what is stored, where, and how to clear it.

## What PromptBar Does Not Do

PromptBar does not request or store any login credentials. It does not collect
analytics, telemetry, or crash reports. It does not include any tracking SDK,
advertising SDK, or remote-configuration framework.

## Authentication Inside Web Chats

When you add a URL that requires sign-in, authentication happens entirely inside
that website's own pages, loaded in `WKWebView`. PromptBar never sees or stores
your credentials. To delete an account on a third-party site, follow that
site's own deletion instructions.

## Local Website Data

`WKWebView` may store cookies, local storage, IndexedDB, caches, and other
website data on your Mac for the sites you load. This keeps your sign-in
sessions across launches.

You can erase all of this at any time from **Menu → Clean Cookies & Cache**.

## App Preferences

PromptBar stores the following on your Mac only:

- Your list of services (names, URLs, icons, colors)
- Your window size preference
- Your "always on top" preference

All of these live in `UserDefaults` for the PromptBar app. Resetting the app
(or removing it via Finder) deletes them.

## Third-Party Sites

When you add a URL to PromptBar, the privacy policy of that site governs any
data you enter there. PromptBar does not endorse, integrate with, or have any
business relationship with the operators of the sites you choose to load.
