# NAR Tracker - iOS App Plan (v2)

## Architecture

```
iPhone App (SwiftUI)
  ├─ UNUserNotificationCenter — local notifications, 5x/day
  ├─ CoreLocation — lat/lon on form open
  ├─ Open-Meteo API — fetch humidity using lat/lon (free, no API key)
  ├─ ASWebAuthenticationSession — Cognito Hosted UI (PKCE OAuth)
  ├─ Keychain — store Cognito tokens
  └─ URLSession POST → API Gateway (JWT auth) → Lambda → DynamoDB
```

---

## Symptoms (1–5 stars each)
- Congestion
- Headaches
- Fatigue
- Mood

## Data per record
| Field | Source |
|---|---|
| `notification_time` | Notification payload — also used as DynamoDB sort key |
| `submission_time` | Device clock at submit |
| `latitude`, `longitude` | CoreLocation |
| `humidity_pct` | Open-Meteo (lat/lon → current humidity) |
| `congestion`, `headaches`, `fatigue`, `mood` | User input (1–5) |
| `date` | **Derived server-side** from `notification_time[:10]` — DynamoDB partition key |

Client sends everything except `date`. Lambda writes it.

---

## Auth (Cognito)
- **Cognito User Pool** with Hosted UI (email/password)
- iOS uses `ASWebAuthenticationSession` + PKCE — standard OAuth, no Amplify needed
- Login once → tokens stored in iOS Keychain
- API Gateway validates JWT — Lambda has zero auth logic
- **Free tier**: 10,000 MAUs/month, permanently free

---

## AWS Infrastructure (CDK — TypeScript)

Single CDK stack provisions everything:
1. Cognito User Pool + User Pool Client (PKCE, callback: `nartracker://callback`)
2. DynamoDB table `nar-symptoms` (partition key: `date`, sort key: `notification_time`)
3. Lambda (Python 3.12) with `PutItem` permission on the table
4. API Gateway HTTP API → `POST /log` → Lambda, protected by Cognito JWT authorizer

CDK outputs the endpoint URL, User Pool ID, and Client ID → paste into `Constants.swift`.

---

## Project Structure

```
nar-tracker/
  cdk/                          ← CDK project (TypeScript / Node.js)
    bin/nar-tracker.ts          — CDK app entry point
    lib/nar-tracker-stack.ts    — all AWS resources defined here
    lambda/lambda_function.py   — ~30 lines, writes to DynamoDB
    package.json
    cdk.json
  ios/
    NARTracker.xcodeproj        ← open this in Xcode
    NARTracker/
      App/NARTrackerApp.swift   — schedule notifications on launch
      Auth/AuthManager.swift    — Cognito PKCE, Keychain
      Form/FormView.swift       — star rating UI + submit
      Form/FormViewModel.swift  — fetch location + humidity, build POST
      Networking/APIClient.swift
      Networking/WeatherClient.swift
      Constants.swift           — endpoint URL, Cognito IDs, notification times
```

---

## Entry Points

### AWS / CDK
```bash
cd cdk
npm install
cdk bootstrap   # one-time: sets up CDK in your AWS account
cdk deploy      # provisions all resources, prints outputs
```
Preview without deploying: `cdk synth` (generates CloudFormation template)

### iOS App
No third-party dependencies — system frameworks only (SwiftUI, CoreLocation,
UserNotifications, AuthenticationServices). No pod install or SPM step.
```
Open ios/NARTracker.xcodeproj in Xcode → Run (⌘R)
```
Must be run on a real device to test notifications and CoreLocation fully.

---

## Notification Schedule (hardcoded)
8:00am · 11:00am · 2:00pm · 5:00pm · 8:00pm — repeating daily

---

## Weather API: Open-Meteo
```
GET https://api.open-meteo.com/v1/forecast
    ?latitude={lat}&longitude={lon}&current=relative_humidity_2m
```
No API key. Free forever. ~1km resolution.

---

## Build Order
1. `cd cdk && npm install && cdk bootstrap && cdk deploy`
2. Create your Cognito user (AWS console or CLI)
3. Fill `Constants.swift` with CDK outputs
4. Open `ios/NARTracker.xcodeproj` → Run on device

---

## Free Tier Summary
| Service | Usage | Free Tier |
|---|---|---|
| DynamoDB | ~150 writes/month | 25 WCU free forever |
| Lambda | ~150 invocations/month | 1M/month free forever |
| API Gateway | ~150 calls/month | 1M/month (12 months, then ~$0.01/mo) |
| Cognito | 1 MAU | 10,000 MAU free forever |
| Open-Meteo | ~150 calls/month | Unlimited, free forever |

---

## Out of Scope (for now)
- Analysis/export
- Additional symptom fields (schema is flexible, easy to add later)
- Settings screen for notification times
- App Store distribution
