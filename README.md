# food-marketplace

A food-ordering marketplace: a backend API and a customer app, in one repository.

| Folder     | What                                         | Built with                      |
|------------|----------------------------------------------|---------------------------------|
| `backend/` | REST API: restaurants, menus, auth, orders   | Express, TypeScript, PostgreSQL |
| `app/`     | Customer app: browse, order, track orders    | Flutter, Riverpod               |

## Run the backend

Needs Node.js (22 or newer) and Docker.

```bash
cd backend
npm install
cp .env.example .env          # then set JWT_SECRET, e.g. to the output of: openssl rand -hex 32
docker compose up -d --wait   # start Postgres
npm run db:migrate            # create or update the tables
npm run db:seed               # demo data; every demo password is password123
npm run dev                   # API on http://localhost:3000
npm test                      # backend tests (use a separate food_test database)
```

## Run the app

Needs Flutter, plus Xcode for iOS or Android Studio for Android. Start the backend first.

```bash
cd app
flutter pub get
flutter run                   # pick the iOS simulator or Android emulator
flutter test                  # fast tests: models, API client, widgets (no backend needed)
```

The app finds the backend at `http://localhost:3000` on the iOS simulator and `http://10.0.2.2:3000` on the Android emulator (the emulator's address for your computer). For anything else, such as a real phone on your Wi-Fi, pass the address:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

Integration tests run the real app on a simulator against the running backend (with the seed data), one file at a time:

```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/place_order_test.dart
```
