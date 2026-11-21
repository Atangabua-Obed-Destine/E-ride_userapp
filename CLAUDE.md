# E-Ride — Customer App (Flutter)

## What this is

The **customer** app of the E-Ride ride-hailing + parcel-delivery platform (a DriveMond-family
product, v3.3). It is one of three clients of a single backend:

- **Backend + admin panel**: a separate Laravel repo at `C:\xampp\htdocs\e-ride`,
  served by XAMPP at `http://localhost/e-ride` (admin panel at `/admin`). It has its own `CLAUDE.md`.
- **Driver app**: a separate Flutter repo, not present on this machine.

Package name is still `ride_sharing_user_app` (see `pubspec.yaml`) — that's the upstream name, not a
different project.

## Architecture

GetX does everything: state management, dependency injection, and navigation.

Per-feature layering under `lib/features/<feature>/` — a strict, repeated chain:

```
controllers/<name>_controller.dart          GetxController, holds UI state
domain/services/<name>_service.dart         business logic  (+ _service_interface.dart)
domain/repositories/<name>_repository.dart  raw API calls   (+ _repository_interface.dart)
domain/models/*.dart                        fromJson/toJson models
screens/ + widgets/                         UI
```

Controllers depend on the **service interface**, services on the **repository interface**. Both
concrete classes and interfaces are registered in `lib/helper/di_container.dart`.

**When adding a feature, copy `lib/features/ride/`** — it's the most complete example of the pattern.

Three files must be touched for almost any new feature:

| File | What to add |
|---|---|
| `lib/util/app_constants.dart` | the endpoint path constant |
| `lib/helper/di_container.dart` | repository, service, controller, and both interfaces |
| `assets/language/en.json` + `fr.json` | any user-facing string |

There are 27 features: ride, trip, parcel, map, set_destination, location, address, payment, wallet,
coupon, my_offer, my_level, refer_and_earn, refund_request, safety_setup, realtime_location_trac,
message, notification, support, profile, auth, onboard, splash, home, dashboard, settings,
maintainance_mode.

Shared code: `lib/common_widgets/` (reusable UI), `lib/helper/` (stateless helpers),
`lib/util/` (constants, dimensions, images, styles), `lib/theme/` (light/dark),
`lib/localization/`, `lib/interface/`.

## Networking

Single client: `lib/data/api_client.dart` (`package:http`, 30s timeout). `lib/data/api_checker.dart`
centralizes error handling.

Every request carries these headers, set in `ApiClient.updateHeader()`:

- `Authorization: Bearer <token>` — a **Laravel Passport** token from `/api/customer/auth/login`,
  persisted in SharedPreferences under `AppConstants.token`.
- `zoneId` — derived from the saved address (`AppConstants.userAddress`). **This matters a lot.**
  Fares, surge pricing, vehicle categories, and driver availability are all zone-scoped server-side.
  A missing or stale `zoneId` produces empty lists and wrong fares rather than an obvious error.
- `X-Localization` — language code, drives backend `translate()`.

`AppConstants.baseUrl` is `http://192.168.137.1/e-ride` — the dev machine's LAN/hotspot IP, **not**
`localhost`, because on a physical device `localhost` resolves to the phone. Change it to match your
network when the machine's IP changes; an emulator can use `10.0.2.2`.

**All endpoint paths live in `AppConstants`** (~90 of them). Never inline a URL in a repository.

## Navigation

`lib/helper/route_helper.dart` is *not* a named-route table — its `GetPage` list is commented out.
Navigation is direct: `Get.to(() => SomeScreen())` / `Get.off` / `Get.offAll`. `RouteHelper` only
holds small navigation utilities (e.g. `goPageAndHideTextField`). Deep links come in through
`app_links` and FCM payloads, handled in `lib/helper/notification_helper.dart`.

## Key flows

### Ride lifecycle

Client state machine `RideState` — `lib/features/ride/controllers/ride_controller.dart:32`:

```
initial → riseFare → findingRider → afterAcceptRider → outForPickup → otpSent → ongoingRide → completeRide
```

Backing API calls (all in `AppConstants`): `estimatedFare` → `rideRequest` →
`biddingList` / `ignoreBidding` → `tripAcceptOrReject` → `updateTripStatus` → `finalFare` →
`paymentUri` → `submitReview`.

`currentRideStatus` (`/api/customer/ride/ride-resume-status`) recovers an in-flight trip when the
app restarts mid-ride — check it before assuming a fresh `initial` state.

Parcel delivery has its own parallel machine, `ParcelDeliveryState` in
`lib/features/parcel/controllers/parcel_controller.dart`.

**Pickup directions and voice note.** `lib/features/ride/widgets/pickup_help.dart`: on Trip Setup
(and the parcel sender form) the customer writes where the driver finds them or records a voice
note. The recording is uploaded first (`AppConstants.assistantVoiceTrip`), the backend keeps it
for the driver and asks the AI to read it (pickup description, destination, parcel details), and
its name travels with `rideRequest` as `voice_note` (`RideController.voiceNote`). The driver app
shows it on the request and on the way to pickup.

### Realtime

`lib/helper/pusher_helper.dart` uses `dart_pusher_channels` against the backend's **Laravel Reverb**
server (Pusher wire protocol, port 6001). It subscribes to per-trip *private* channels, each
authorized through the backend's broadcasting auth endpoint:

| Channel | Effect in the app |
|---|---|
| `private-driver-trip-accepted.{tripId}` | refetch trip details, move to `afterAcceptRider` |
| `private-driver-trip-started.{tripId}` | refetch details + final fare, move to `ongoingRide` |
| `private-driver-trip-cancelled.{tripId}` | reset ride state |
| `private-driver-trip-completed.{tripId}` | final fare, then `ReviewScreen` |
| `private-driver-payment-received.{tripId}` | payment confirmed, then `ReviewScreen` |

FCM (`lib/helper/notification_helper.dart`) is the out-of-app path for the same lifecycle events.
Firebase project `e-ride-38f60`: Android reads `android/app/google-services.json`, iOS reads
`ios/GoogleService-Info.plist` (the copy Xcode bundles; `ios/Runner/` holds the same file).

### Configuration

`/api/customer/configuration` → `lib/features/splash/domain/models/config_model.dart`, fetched by
`ConfigController` at splash. It gates feature toggles, currency and symbol position, maintenance
mode, minimum app version, available payment methods, and which login methods are enabled. **A
setting changed in the admin panel reaches the app through this response** — if a feature "isn't
showing up", check the config payload before the widget code.

## iOS

There is no Mac on the team: iOS is built on Codemagic (`codemagic.yaml`, workflows `ios-device` and
`ios-simulator`, both unsigned until the Apple Developer account exists). Bundle ID `com.innova.eride`
(the Android id `com.i_nnova.eride` is not valid on iOS); the live activity extension is
`com.innova.eride.TripLiveActivity`.

The GitHub repo is public, so the Google Maps key must not reach it: Codemagic builds from the
`ios-build` branch, a snapshot of the working branch with the key replaced by `MAPS_API_KEY_HERE`
(the build puts it back from the `MAPS_API_KEY` secret). Publish with
`bash tool/publish_ios_build.sh`; never push the working branch itself.

## Conventions & gotchas

- Strings: `'some_key'.tr`, defined in `assets/language/en.json` and `fr.json`. Both files must be
  updated or the French build shows raw keys.
- `AppConstants` status strings (`pending`, `accepted`, `ongoing`, `completed`, `cancelled`,
  `returning`, `returned`, `out_for_pickup`) **mirror the backend's `app/Lib/Constant.php`** and must
  stay in sync with it.
- Fonts are SFProText (default) and Roboto; sizes in `lib/util/dimensions.dart`, colors via
  `Theme.of(context)` — don't hardcode either.
- Images/SVGs are referenced through `lib/util/images.dart`, not raw asset paths.
- Lint: `flutter analyze` (uses `flutter_lints` via `analysis_options.yaml`).
- `build/`, `logcat.txt`, and `emulator_screen.png` at the repo root are local artifacts, not source.
