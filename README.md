# Little Lemon · Chicago restaurant menu

A SwiftUI restaurant app for the Meta iOS App Capstone. The app and its home-screen wireframe were prepared with AI assistance.

## Run in Xcode

Open **Little Lemon.xcodeproj**, select the **Little Lemon** target and an iPhone simulator running **iOS 16 or later**, then choose **Product → Run**. No account, key or package installation is needed for simulator use.

## Try the app

1. Enter a first and last name, use Next to enter an email address, and choose notification preferences on the third page. Finish registration to open the menu.
2. Select a category, search for part of a dish name, or sort the menu by name or price. Open a dish to see its description and add it to the bag. The demo checkout displays the total and confirmation locally.
3. Tap the initials at the top right to open Profile. Save a change and relaunch to verify persistence. Discard changes or use the navigation back button to leave edits unsaved.
4. Log out to clear the guest profile and start registration again. The shared restaurant menu remains available offline.

## Design and data

The [home wireframe](Design/Home-wireframe.jpg) shows the header, restaurant introduction, search, category filters and dish list. The [editable vector source](Design/Home-wireframe.svg) can be imported into Figma.

The app fetches [Meta’s course menu](https://github.com/Meta-Mobile-Developer-PC/Working-With-Data-API/blob/main/menu.json) and uses the item photo links from that feed. A copy of the menu ships with the app for first launch. Successful refreshes update the device’s Core Data store by dish ID. Pull down to retry a refresh. Photos need a network connection unless already cached.

## Verification

The Swift source files were checked with a syntax parser, and the Xcode target’s source and resource references were checked against the files in the repository. The menu fixture contains five unique dishes. An Xcode build and an iOS simulator run still need verification on a Mac.
