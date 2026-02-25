# Good Espresso - App Store Submission Guide

## App Store Connect Metadata

### App Information

**App Name:** Good Espresso

**Subtitle:** Control Your Decent Machine

**Category:** Food & Drink (Primary), Utilities (Secondary)

**Content Rights:** This app does not contain, show, or access third-party content.

**Age Rating:** 4+ (No objectionable content)

### Description

```
Good Espresso brings professional espresso control to your fingertips. Connect wirelessly to your Decent espresso machine and unlock the full potential of precision coffee brewing.

FEATURES:

• Real-Time Monitoring
Watch pressure, flow, and temperature in real-time with beautiful live charts. Track every aspect of your extraction as it happens.

• Professional Profiles
Choose from 11 expertly crafted espresso profiles and 6 pulse-brew tea profiles. From classic E61 to modern turbo shots, find the perfect profile for your beans.

• Easy Profile Editing
Edit any profile with a tap. Duplicate & customize built-in profiles or create your own from scratch with the step-by-step editor.

• Pulse-Brew Tea
Experience traditional gongfu-style tea brewing with innovative pulse profiles. The basket fills, pressure opens the valve, then alternating steep and pulse cycles extract maximum flavor.

• Shot History
Review past extractions with detailed charts and data. Rate your shots and track your progress over time.

• Complete Machine Control
Access all machine functions including espresso, steam, flush, hot water, sleep, wake, clean, and descale modes.

• Native Mac & iPad Support
Enjoy a full sidebar navigation layout on iPad and Mac with content that scales beautifully to any window size.

IMPORTANT NOTICE:
Good Espresso is an independent, open-source application. It is NOT affiliated with, endorsed by, or officially connected to Decent Espresso. Use at your own risk.

REQUIREMENTS:
• Decent espresso machine (DE1, DE1+, DE1PRO, or DE1XL)
• iPhone, iPad, or Mac with Bluetooth LE support
• iOS 16.0 or later
```

### Keywords

```
espresso, coffee, decent, brewing, barista, extraction, pressure, profiling, tea, macOS
```

### What's New (Version 1.1)

```
NEW IN 1.1:

• Mac Catalyst & iPad Sidebar
Full NavigationSplitView sidebar on iPad and Mac. No more tab bar on wide screens — switch between Home, Profiles, Control, History, and Settings from a proper sidebar.

• Easy Profile Editing
Edit button is now front and center on every profile. Custom profiles get a direct "Edit Profile" button; built-in profiles get "Duplicate & Edit" to create your own version in one tap.

• Improved macOS Layout
Content no longer stretches across ultra-wide windows. Cards and controls cap at sensible widths, the sidebar column is resizable, and the profile visualization adapts to your window size.

• Cross-Platform Fixes
Resolved compatibility issues with List selection, list styles, and system colors across iOS, iPadOS, and macOS.
```

### What's New (Version 1.0)

```
Initial release featuring:
• Bluetooth connection to Decent machines
• Real-time extraction monitoring
• 17 professional brewing profiles
• Pulse-brew tea profiles
• Shot history and rating
• Complete machine controls
```

### Support URL

```
https://github.com/goodespresso/app
```

### Privacy Policy URL

```
https://github.com/goodespresso/app/blob/main/PRIVACY.md
```

---

## Screenshots Required

### iPhone 6.7" Display (iPhone 15 Pro Max)
1. **Home Screen** - Connected state showing machine status and chart
2. **Control Screen** - Live extraction with real-time chart
3. **Profiles Screen** - List of espresso and tea profiles
4. **Profile Detail** - Detailed view of a profile with Edit button visible
5. **History Screen** - Shot history with ratings

### iPhone 6.5" Display (iPhone 14 Plus)
- Same 5 screenshots

### iPhone 5.5" Display (iPhone 8 Plus)
- Same 5 screenshots

### iPad Pro 12.9" (6th gen)
1. **Home Screen** - Sidebar + two-column dashboard layout
2. **Control Screen** - Sidebar + centered control panel
3. **Profiles Screen** - Sidebar + profile list with search
4. **Profile Detail** - Sidebar + profile detail with Edit button
5. **Settings Screen** - Sidebar + settings list

### Mac (via Mac Catalyst)
- Same 5 screenshots as iPad, captured in a Mac window

---

## App Review Information

### Demo Account
Not applicable - app uses Bluetooth to connect to physical hardware.

### Notes for Reviewer

```
This app requires a Decent espresso machine to demonstrate full functionality. The app will show a "Not Connected" state without the physical machine.

Key features that can be reviewed without hardware:
1. Profile browsing and editing (Profiles tab)
2. Duplicate & Edit flow on any profile
3. Legal disclaimers (shown on first launch)
4. Settings and preferences
5. App navigation: tab bar on iPhone, sidebar on iPad/Mac
6. Window resizing behavior on Mac

The app is an open-source community project for controlling Decent espresso machines via Bluetooth. It does not collect any user data and stores all information locally on the device.
```

### Contact Information
- First Name: [Your Name]
- Last Name: [Your Last Name]
- Phone: [Your Phone]
- Email: [Your Email]

---

## Required Assets

### App Icon (1024x1024)
Create an icon featuring:
- Coffee cup or espresso portafilter
- Orange/brown color scheme
- Clean, modern design
- No text (App Store guidelines)

### Screenshots
Capture on:
- iPhone 15 Pro Max (6.7")
- iPhone 14 Plus (6.5")
- iPhone 8 Plus (5.5")
- iPad Pro 12.9"
- Mac (via Catalyst)

---

## Privacy Policy (Required)

Create a file at `PRIVACY.md`:

```markdown
# Privacy Policy for Good Espresso

Last updated: February 2026

## Overview

Good Espresso is committed to protecting your privacy. This app does not collect, store, or transmit any personal information to external servers.

## Data Collection

**We do NOT collect:**
- Personal information
- Usage analytics
- Location data
- Device identifiers
- Any data transmitted to third parties

## Local Storage

The app stores the following data locally on your device:
- Shot history and extraction data
- User preferences and settings
- Brewing profiles

This data never leaves your device and is not accessible to us or any third party.

## Bluetooth

The app uses Bluetooth to communicate directly with your Decent espresso machine. This communication is:
- Direct between your device and machine
- Not routed through any external servers
- Not logged or recorded by us

## Data Deletion

All locally stored data can be deleted by:
- Using the "Clear History" option in Settings
- Uninstalling the app

## Children's Privacy

This app does not collect any information from anyone, including children under 13.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted in the app and on our GitHub repository.

## Contact

For questions about this privacy policy, please open an issue on our GitHub repository.
```

---

## Submission Checklist

- [ ] App icon (1024x1024 PNG, no alpha)
- [ ] Screenshots for all required device sizes (including iPad sidebar layout)
- [ ] Mac Catalyst screenshots showing sidebar navigation
- [ ] App description updated for v1.1
- [ ] What's New text updated for v1.1
- [ ] Keywords updated
- [ ] Support URL active
- [ ] Privacy Policy URL active
- [ ] Privacy manifest (PrivacyInfo.xcprivacy) included
- [ ] Age rating questionnaire completed
- [ ] Pricing set (Free)
- [ ] Availability (all countries or specific)
- [ ] Build uploaded via Xcode/Transporter
- [ ] Export compliance answered (No encryption = exempt)
- [ ] Content rights declared
- [ ] Version set to 1.1.0, build 2

---

## Export Compliance

When asked about encryption:
- Select "No" for "Does your app use encryption?"
- The app only uses standard iOS Bluetooth APIs
- No custom encryption is implemented

---

## Build & Upload Process

1. **In Xcode:**
   - Verify version 1.1.0, build 2
   - Select "Any iOS Device (arm64)"
   - Product > Archive

2. **After Archive:**
   - Window > Organizer
   - Select the archive
   - Click "Distribute App"
   - Select "App Store Connect"
   - Follow prompts to upload

3. **In App Store Connect:**
   - Wait for build processing (5-30 minutes)
   - Select build for submission
   - Update "What's New" text for v1.1
   - Update description if needed
   - Submit for review

---

## Common Rejection Reasons to Avoid

1. **Incomplete Information** - Ensure all fields are filled
2. **Broken Links** - Test support and privacy URLs
3. **Poor Screenshots** - Use real device screenshots, not simulator
4. **Bluetooth Without Purpose** - Clearly explain why Bluetooth is needed
5. **Third-Party Trademarks** - Don't use "Decent" in app name/icon
6. **Guideline 4.2 (Minimum Functionality)** - App has substantial features
7. **Missing Privacy Manifest** - Include PrivacyInfo.xcprivacy for iOS 17+
