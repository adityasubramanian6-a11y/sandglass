# Put Sandglass on your iPhone, step by step

You need a Mac, your iPhone, a USB cable (for the first time), and an Apple ID.
The whole process takes about 20 minutes the first time, mostly waiting for Xcode to download.

## 1. Install Xcode (one time)

1. On your Mac, open the **App Store**, search for **Xcode** and click **Get**. It is free but large (a few GB).
2. Open Xcode once it's installed. If it asks to install extra components or the iOS platform, click **Install** and wait.

## 2. Add your Apple ID to Xcode (one time)

1. In Xcode's menu bar choose **Xcode › Settings…** (or **Preferences…**) and open the **Accounts** tab.
2. Click **+** at the bottom left, choose **Apple ID**, and sign in.
3. Close the window. A free Apple ID is enough; you'll appear as "(Personal Team)".

## 3. Get the project onto your Mac

Open **Terminal** and paste these lines (replace `yourname` with anything unique, e.g. `adit`):

```
brew install xcodegen
git clone https://github.com/adityasubramanian6-a11y/sandglass.git ~/sandglass
cd ~/sandglass
sed -i '' 's/com.example.sandglass/com.yourname.sandglass/g' project.yml
xcodegen generate
open Sandglass.xcodeproj
```

No Homebrew? Install it first from https://brew.sh (one line in Terminal).

## 4. Sign the app with your Apple ID

1. In Xcode's left sidebar, click the blue **Sandglass** icon at the very top.
2. Under **TARGETS**, click **Sandglass**, then the **Signing & Capabilities** tab.
3. Tick **Automatically manage signing** and set **Team** to your name (Personal Team).
4. Under **TARGETS**, click **SandglassWidgets** and set the same **Team** there too.
5. If a red error mentions **App Groups**: on each target's Signing & Capabilities tab, click the small
   **×** next to **App Groups** to remove it. Everything still works except that the widgets always say
   "Flip your iPhone to start".

## 5. Get your iPhone ready (one time)

1. Plug the iPhone into the Mac with a cable and unlock it. If it asks **Trust This Computer?**, tap **Trust**.
2. Turn on Developer Mode: on the iPhone go to **Settings › Privacy & Security › Developer Mode**, switch it on and let the phone restart. (The option appears after the phone has been connected to Xcode once; if you don't see it yet, do step 6 first and come back.)

## 6. Run it

1. At the top of the Xcode window, make sure the scheme says **Sandglass**, then click the device menu (it may say "Any iOS Device" or a simulator name) and pick **your iPhone**.
2. Press the **▶ Run** button (or **⌘R**). The first build takes a minute or two.
3. The first time, the iPhone may refuse to open the app with "Untrusted Developer". On the iPhone go to **Settings › General › VPN & Device Management**, tap your Apple ID under **Developer App**, and tap **Trust**.
4. Press **▶ Run** again. Sandglass opens on your phone.

## 7. Try it out

- Flip the phone upside down: the sand starts running and the focus timer begins.
- Tilt it: the sand stays level. Turn it sideways: it pauses.
- Lock the phone: the Lock Screen shows the hourglass and countdown (and the Dynamic Island, if your iPhone has one).
- Add the widgets: long-press the Home Screen or Lock Screen › **Edit** / **Customize** › **Add Widget** › **Sandglass**.
- The first time a session starts, allow notifications so you hear when time is up.

## Good to know

- With a free Apple ID, the app stops opening after **7 days**. Plug in and press **▶ Run** again to renew it; your settings are kept.
- After the first time, you can run it without a cable: in Xcode choose **Window › Devices and Simulators**, select your iPhone and tick **Connect via network**.
- If Xcode shows an error you can't get past, copy the red message (or take a screenshot) and send it in the project thread.
