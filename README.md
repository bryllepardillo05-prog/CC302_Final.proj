# AmbulanceLink

AmbulanceLink is a Flutter app for managing hospital contacts, ambulance
vehicles, drivers, and emergency request records.

## Features

- Create, view, edit, and delete hospitals, ambulances, drivers, and requests.
- Choose a saved hospital and use guided status choices when entering records.
- Review available ambulance and driver counts on the dashboard.
- Save data locally on the device with `shared_preferences`.
- Users can create an account from the sign-in screen. Account data is stored
  locally on the device; users can submit and view emergency requests, while
  hospital admins can manage all records.

Authentication is a local prototype feature, not production authentication.
Use a secure server-side identity provider before deploying this app for real
users. Passwords are hashed on-device but are not protected by a server.

This is a local prototype. It does not dispatch vehicles or contact emergency
services. For a real emergency, contact local emergency services directly.

## Run

```sh
flutter pub get
flutter run
```

## Validate

```sh
flutter analyze
flutter test
```
