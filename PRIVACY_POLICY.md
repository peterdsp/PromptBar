# Privacy Policy

Last Updated: 25/05/2026

## 1. Introduction

PromptBar is a macOS menu bar client for third-party AI chat websites. This policy explains what PromptBar itself handles and what is handled by the AI providers you choose to use.

## 2. Data Collection and Processing

PromptBar does not ask for, store, or transmit provider API keys. Users authenticate only inside the provider web sessions shown in the app.

PromptBar does not log, inspect, or upload your chat messages. Messages, account details, and provider-side history are processed by the selected AI provider under that provider's own terms and privacy policy.

PromptBar currently uses Firebase Remote Config to fetch app configuration such as available chat providers and update metadata. Firebase Analytics is not linked in the app target.

## 3. Authentication and Accounts

Some providers require sign-in. Authentication is handled inside the provider website loaded in WebKit. PromptBar does not manage provider accounts and does not store provider passwords.

## 4. Local Storage

PromptBar stores local preferences on your Mac, such as selected provider and window size.

Because PromptBar uses `WKWebView` with the default website data store, WebKit may store provider cookies, local storage, IndexedDB, caches, and other website data locally on your Mac. This is how provider sign-in sessions can remain available between launches.

PromptBar includes a cookie and website data clearing action. Using it removes WebKit website data from the app's default data store and reloads the web view.

## 5. Third-Party Services

PromptBar integrates with third-party AI websites. Their privacy policies apply to data you enter into those services:

- [Mistral AI Privacy Policy](https://mistral.ai/privacy-policy/)
- [OpenAI Privacy Policy](https://openai.com/policies/privacy-policy)
- [Google Privacy Policy](https://policies.google.com/privacy)
- [DeepSeek Privacy Policy](https://deepseek.com/privacy-policy)
- [xAI Privacy Policy](https://x.ai/privacy)

## 6. Changes to This Policy

This Privacy Policy may be updated periodically. Significant changes will be communicated through the project repository.

## 7. Contact

For questions or concerns, visit the [GitHub repository](https://github.com/peterdsp/PromptBar) or contact the project maintainer.
