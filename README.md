# Setlog (ECS 191 clone)

The app that I am choosing to clone is Setlog, a Korean mini-vlog mobile app. This app allows users to share short two-second clips with their friends for each hour of the day. I love how simple it makes keeping up with your friends, so I wanted to build my own version of it. My version is a native iOS app written in Swift.

## How to Build and Run the App

To build and run the app, you will need a Mac with Xcode 16 or newer. I built it with Xcode 27. The app targets iOS 18, so make sure the phone/simulator you use is on iOS 18 or later.

### In Xcode (easiest)
1. Clone the repo and open the project:
   ```bash
   git clone https://github.com/haylietan/yday.git
   cd yday
   open Setlog/Setlog.xcodeproj
   ```
2. Pick the Setlog scheme and an iPhone simulator running iOS 18+ from the toolbar. If you only see older simulators, you can download a newer one in Xcode --> Settings --> Components.
3. Press ⌘R to build and run.

### On a real iPhone
1. Plug in your iPhone and select it as the run destination.
2. In the Setlog target, open Signing & Capabilities and choose your Team (a free Apple ID works).
   - If Xcode says the bundle ID is taken, you can change `com.haylietan.Setlog` to something unique.
3. Press ⌘R. The first time, you'll need to trust the developer on your phone under Settings --> General --> VPN & Device Management.
4. Allow camera and microphone access when it asks. It will also ask for Photos access the first time you save a vlog.

### From the command line
```bash
cd Setlog
xcodebuild -project Setlog.xcodeproj -scheme Setlog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
You can run `xcrun simctl list devices available` to see which simulator names you have installed.

## Trying It Out in the Simulator

Since the Simulator doesn't have a camera, the app uses a simulated one instead. When you press the shutter, it still creates a real 2-second video, so you can try out recording, playback, and the archive without needing a phone.

If you'd like to see the app with some content right away, long-press the "SETLOG" logo in the top left. This fills in takes for about the last two weeks, plus the earlier hours of today. (This only works in debug builds.)

I also added a couple of launch arguments you can set in Xcode (Product --> Scheme --> Edit Scheme --> Run --> Arguments):

- `-SetlogSeed YES` loads the demo takes when the app launches
- `-SetlogTab take`, `-SetlogTab dial`, or `-SetlogTab archive` opens the app on that tab

## The App's Main Features

There are four tabs along the bottom: Vlog, 2s Take, Dial, and Archive. At the top, there's a room picker (like "Room 01 · 262"), your time zone, and a little clock icon with a ring that slowly fills up as your day goes on.

### Rooms
Rooms are small and private groups of users, kind of similar to the close friends feature on Instagram. I think this is one of the best parts of Setlog, because having fewer people watch your vlogs takes away a lot of the pressure behind posting. The app also comes with three rooms as default (based off my own friend groups):

- 262 housemates
- 7 baddies 5 porche
- saja boys

Choosing a room in the header changes which friends you see on the Dial page. When you record a take, you get to decide which rooms can see it through the picker as well.

### Vlog (home page)
This is the first page you see when you open the app. It plays all of your takes from the day back to back, so your day comes together as one little vlog.

The bar at the top has one segment for each take. You can tap the video to pause it and use the speaker button to mute it. The arrows at the top let you look back at earlier days. Under the video, Daily Chapters shows a thumbnail for every take, so you can tap any of them to jump straight to it.

Save Day Vlog puts the whole day together into one vertical video and saves it to your camera roll. Share does the same thing, but opens the share sheet so you can send it to someone. Landscape takes get borders above and below the video so they still fit nicely in the vertical video.

### 2s Take (camera)
1. The chip in the top left (like "22:00 SLOT") shows which hour you're recording for. You get one take per hour.
2. Choose which rooms you'd like to send it to. The filled-in ones are selected.
3. If you'd like, you can add a quick thought in the text box (up to 40 characters).
4. Tap or hold the shutter. It records exactly 2 seconds and stops on its own, and the ring around the button fills up while it's recording.
5. A little message will pop up letting you know which rooms it was sent to.

There's also a flash button (back camera only), a flip button to switch cameras, and a badge in the corner that says PORTRAIT or LANDSCAPE. On a real phone, it follows how you're holding it, so you can film whichever way feels natural. In the Simulator, since you can't do that, you can tap it to switch it.

Once you've taken your clip for the hour, the camera immediately locks until the next hour starts. There are no retakes which is intentional. I want each take to be a real and authentic and prevent users from over-curating their content.

### Dial
This page gives you an overview of your whole day.

The big ring has 24 segments, one for each hour of the day. The pink ones are hours you've captured, and the dark dot shows where you are right now. Under it, you can see how many slots are left today and how long until the next one opens.

Below that, there's a small prompt for the current hour, like "Silo lunch, honestly" or "Golden hour in the Arboretum," to give you a little inspiration. The button takes you to the camera or to today's vlog if you've already taken your clip.

At the bottom, Recent Room Moments shows your own takes and your friends' posts for whichever room you have selected in the picker above.

### Archive
This is a calendar of every day you've logged, and it serves as a way for users to look back on past memories. You can use the arrows to switch between months. The top shows how many seconds you logged that month, how many takes you recorded, and your retakes (which will always be 0).

Days with takes are highlighted, and the little ring on each day shows how much of it you captured. Tap a day to see a preview, then press Play Vlog to rewatch it or the share button to send it to someone.

## What I Kept and Changed From the Original

I kept the core feature of Setlog, which as a 2-second clip for each hour of the day with small private rooms. Each day's clips are able to be compiled together into one video. And I added calendar where you can look back into past days.

Like I mentioned in my proposal, I also made a few changes:

- You can't retake a clip. I think the whole purpose of the app is to be real and being able to retake videos only adds to overthinking/over-curating of content.
- I removed comments and reactions. I want users to focus on documenting their day without feeling like they need to show support to everyone else. My goal is to make documenting daily life feel like second nature.
- You can record in portrait or landscape. The original app SetLog only accepts horizontal recordings, so this gives you a little more freedom.

For the design, I went with a pink background, white cards with black outlines, and reddish pink accents. My goal was to make it feel calm and cozy.

## Project Structure

```
Setlog/
├── Setlog.xcodeproj
└── Setlog/
    ├── SetlogApp.swift            # where the app starts
    ├── Theme.swift                # colors, fonts, and shared UI pieces
    ├── Model/
    │   ├── Models.swift           # clips, rooms, friends, sample posts
    │   └── SetlogStore.swift      # saving clips, the one-take-per-hour rule, demo data
    ├── Services/
    │   ├── CameraService.swift    # recording the 2-second takes
    │   ├── SimulatedClipWriter.swift  # simulated camera for the Simulator
    │   └── ReelComposer.swift     # putting clips together and saving to Photos
    ├── Views/
    │   ├── RootView.swift         # header, room picker, tab bar
    │   ├── ReelView.swift         # Vlog tab (home)
    │   ├── CaptureView.swift      # 2s Take camera
    │   ├── DialView.swift         # Dial tab
    │   ├── ArchiveView.swift      # Archive calendar
    │   └── VideoViews.swift       # video player, camera preview, share sheet
    └── Assets.xcassets
```

Your takes are saved on your phone in the app's Documents folder, so they'll still be there after you close the app.

## Known Limitations

- There's no backend yet, so the friends and their posts are sample data for now. Only your own takes are real.
- The design I based it on uses the Space Grotesk and Inter fonts, but I used the iPhone's built-in font so I didn't need to bundle anything extra.
- I haven't made an app icon yet.
- If the room names change, takes recorded under the old rooms won't show up in any room's feed. Deleting and reinstalling the app will clear them out.