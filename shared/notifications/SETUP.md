# Push notifications setup (FCM) — step by step

Chkela already has the app + admin wiring. Follow these steps once so real pushes work on phones.

**IDs used in this project** (must match published chkela101 / store listing)
- Android application id: `com.chkela.v1`
- iOS bundle id: `com.lolearn.chkela`
- Firebase project: `chkela-25bd7`
- App version for this update: `1.2.0+20` (published was `1.1.9`)
- Apple team: `BF6LKNCG8Z`

---

## Step 1 — Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** → name it (e.g. `chkela`) → continue
3. Google Analytics is optional → create the project

---

## Step 2 — Add the Android app

1. In the project overview, click the **Android** icon
2. Android package name: `com.chkela.v1`
3. Register the app
4. Download **`google-services.json`**
5. Put it here (exact path):

```text
android/app/google-services.json
```

6. You can skip the Firebase SDK snippets in the console — FlutterFire handles that later

---

## Step 3 — Add the iOS app

1. In Firebase project overview, click **Add app** → **iOS**
2. iOS bundle ID: `com.lolearn.chkela`
3. Register the app
4. Download **`GoogleService-Info.plist`**
5. Put it here (exact path):

```text
ios/Runner/GoogleService-Info.plist
```

6. In Xcode later: open `ios/Runner.xcworkspace`, confirm the plist is in the **Runner** target

### iOS push capability (required for real device push)

1. Apple Developer account → create an **APNs key** (Keys → +)
2. Firebase Console → Project settings → **Cloud Messaging** → **Apple app configuration**
3. Upload the APNs Authentication Key (`.p8`), Key ID, and Team ID

Without this, Android may work while iOS does not.

---

## Step 4 — Generate Flutter Firebase options

In Terminal, from the **Chkela 2** project root:

```bash
cd "/Users/macbookpro/Downloads/Chkela 2"

# one-time
dart pub global activate flutterfire_cli

# log in if prompted, select your Firebase project + Android/iOS apps
flutterfire configure
```

This rewrites `lib/firebase_options.dart` with real keys.

**Check it worked:** open `lib/firebase_options.dart` and confirm `projectId` is **not** `YOUR_PROJECT_ID`.

---

## Step 5 — Enable the Android Google Services Gradle plugin

### 5a. Edit `android/settings.gradle.kts`

In the `plugins { ... }` block, add:

```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

### 5b. Edit `android/app/build.gradle.kts`

In the top `plugins { ... }` block, add:

```kotlin
id("com.google.gms.google-services")
```

Sync / rebuild Android after this.

---

## Step 6 — Allow the dashboard to send pushes (service account)

1. Firebase Console → gear icon → **Project settings**
2. Tab **Service accounts**
3. Click **Generate new private key** → download the JSON
4. Save/rename it to this exact path:

```text
shared/notifications/serviceAccount.json
```

**Do not commit this file** (it is gitignored).

5. Restart the dashboard so it picks up the file:

```bash
cd "/Users/macbookpro/Downloads/Chkela 2/dashboard"
npm run dev -- --port 5173 --host 127.0.0.1
```

6. Open **Notifications** in the admin sidebar  
   - **FCM server** should show **Ready**  
   - If it still says Setup needed, the JSON path/name is wrong

---

## Step 7 — Run and test

### Start dashboard

```bash
cd "/Users/macbookpro/Downloads/Chkela 2/dashboard"
npm run dev -- --port 5173 --host 127.0.0.1
```

### Run the app on a real phone

```bash
cd "/Users/macbookpro/Downloads/Chkela 2"
flutter run
```

Use a **physical device**. Simulators/emulators are unreliable for push; Chrome web is skipped for now.

### Sign in

1. Open the app → verify OTP / finish login  
2. Allow notification permission when asked  
3. In dashboard → **Notifications** → **Registered devices**  
   - You should see your phone number + platform + token

### Send a test

1. Dashboard → **Notifications**
2. Title / body → **Send** (leave phone empty for all devices, or enter `+251…` for one student)
3. Status should become **sent** (not `stored_only`)

---

## Quick checklist

| Step | Done when… |
|------|------------|
| Firebase project | Project exists in console |
| Android config file | `android/app/google-services.json` present |
| iOS config file | `ios/Runner/GoogleService-Info.plist` present |
| APNs key (iOS) | Uploaded in Firebase Cloud Messaging |
| Flutter options | `flutterfire configure` ran; real `projectId` |
| Gradle plugin | google-services plugin added in both gradle files |
| Service account | `shared/notifications/serviceAccount.json` present |
| Dashboard | Notifications shows **FCM server: Ready** |
| Device | Token appears after sign-in on a real phone |
| Send | Message status is **sent** |

---

## Troubleshooting

**Push still disabled in app logs**  
`Push: Firebase not configured yet` → `flutterfire configure` not done, or `projectId` still placeholder.

**FCM server: Setup needed**  
Missing/wrong `shared/notifications/serviceAccount.json`, or dashboard not restarted.

**No registered devices**  
App must be signed in on a real device with notification permission allowed; dashboard must be reachable at `127.0.0.1:5173` (use your Mac’s LAN IP if testing on a physical phone).

**iOS never receives**  
APNs key missing in Firebase; also rebuild the iOS app after adding the plist.

**Android build fails after Gradle change**  
Confirm `google-services.json` is under `android/app/` before applying the plugin.

**Phone on device can’t reach dashboard**  
Change the app API base (same pattern as content API) to your Mac’s LAN IP instead of `127.0.0.1` when testing on hardware.
