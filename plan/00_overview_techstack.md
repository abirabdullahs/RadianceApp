# 🌟 Radiance Coaching Center — Android App
## Project Overview & Tech Stack

---

## 📌 App Summary

**App Name:** Radiance  
**Target:** Physical coaching center management — SSC/HSC students  
**Platform:** Android (Google Play Store)  
**Framework:** Flutter  
**Users:** Admin (Teacher/Owner) + Students  
**Language Support:** Bengali + English  

---

## 🏗️ Tech Stack — Flutter + Supabase + Firebase

| Layer | Technology | কেন |
|---|---|---|
| **Framework** | Flutter (Dart) | Native performance, pixel-perfect UI, Google-backed |
| **Language** | Dart | Type-safe, OOP, শিখতে সহজ |
| **Navigation** | GoRouter | Declarative routing, deep link support |
| **State Management** | Riverpod (flutter_riverpod) | Best-in-class, testable, scalable |
| **Backend** | Supabase | Postgres DB, Auth, Storage, Realtime |
| **Auth** | Supabase Auth (Phone OTP) | SMS OTP দিয়ে login |
| **Database** | PostgreSQL (via Supabase) | Relational, payments/attendance-এর জন্য perfect |
| **File Storage** | Supabase Storage | Thumbnails, PDF notes, videos |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Android push notifications |
| **Notification Trigger** | Supabase Edge Functions → FCM | Server-side trigger |
| **SMS** | SSL Wireless / BulkSMS BD | Local SMS gateway |
| **PDF Generation** | `pdf` dart package | Voucher, result card, attendance sheet |
| **Video** | youtube_player_flutter | Class recordings |
| **Local Storage** | Hive + shared_preferences | Offline cache, settings |
| **Charts** | fl_chart | Dashboard analytics |
| **Community/Chat** | Supabase Realtime | Group messaging |
| **LaTeX Rendering** | flutter_math_fork | Exam questions (math/chemistry) |
| **Build** | `flutter build appbundle` | `.aab` → Play Store |

---

## 🔥 Firebase — শুধু Notification এর জন্য

Firebase এ শুধু **FCM** use হবে। Firestore বা Firebase Auth না।

```
Admin কোনো action করে (payment add, result publish)
        ↓
Supabase Database update হয়
        ↓
Supabase Edge Function trigger হয় (Deno runtime)
        ↓
Edge Function → FCM HTTP v1 API call করে
        ↓
Student-এর Android device-এ push notification আসে
```

### Firebase Services Used:
| Service | Purpose |
|---|---|
| Firebase Cloud Messaging (FCM) | Push notifications |
| Firebase Analytics (optional) | Usage tracking |

---

## ⚡ Flutter vs React Native — কেন Flutter বেছে নিলে?

| Criteria | Flutter | React Native |
|---|---|---|
| Performance | ✅ Compiled to native (Impeller engine) | ⚠️ JS Bridge overhead |
| UI Consistency | ✅ Pixel-perfect, same on all Android devices | ⚠️ Platform-specific differences |
| Bengali Font | ✅ Excellent (google_fonts → Hind Siliguri) | ✅ Works |
| PDF Generation | ✅ `pdf` package — very powerful | ⚠️ Limited options |
| Google Play | ✅ Google-backed, best Android support | ✅ Works |
| Hot Reload | ✅ Instant | ✅ Instant |
| Learning | ⚠️ Dart শিখতে হবে (~2 weeks) | — |

---

## 📁 Flutter Project Structure

```
radiance_app/
├── android/
│   └── app/
│       └── google-services.json       ← Firebase config
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart          ← FlutterFire CLI generated
│   ├── app/
│   │   ├── router.dart                ← GoRouter setup
│   │   └── theme.dart                 ← Colors, fonts, theme
│   ├── core/
│   │   ├── supabase_client.dart
│   │   ├── constants.dart
│   │   └── services/
│   │       ├── fcm_service.dart       ← FCM token management
│   │       ├── pdf_service.dart       ← Voucher/result PDF
│   │       ├── sms_service.dart       ← SMS API calls
│   │       └── storage_service.dart   ← File upload/download
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/login_screen.dart
│   │   │   ├── screens/signup_screen.dart
│   │   │   ├── providers/auth_provider.dart
│   │   │   └── repositories/auth_repo.dart
│   │   ├── home/                      ← Public home page
│   │   ├── admin/
│   │   │   ├── dashboard/
│   │   │   ├── courses/
│   │   │   ├── students/
│   │   │   ├── payments/
│   │   │   ├── attendance/
│   │   │   ├── exams/
│   │   │   ├── results/
│   │   │   ├── notifications/
│   │   │   └── settings/
│   │   └── student/
│   │       ├── dashboard/
│   │       ├── courses/
│   │       ├── notes/
│   │       ├── attendance/
│   │       ├── payments/
│   │       ├── exams/
│   │       ├── results/
│   │       ├── community/
│   │       ├── qbank/
│   │       ├── suggestions/
│   │       ├── complaints/
│   │       └── profile/
│   └── shared/
│       ├── widgets/
│       │   ├── app_button.dart
│       │   ├── app_card.dart
│       │   ├── loading_overlay.dart
│       │   └── empty_state.dart
│       └── models/
│           ├── user_model.dart
│           ├── course_model.dart
│           ├── payment_model.dart
│           └── ...
├── supabase/
│   ├── migrations/                    ← SQL schema files
│   └── functions/
│       ├── send-notification/         ← FCM trigger
│       │   └── index.ts
│       └── generate-monthly-dues/     ← Auto due creation
│           └── index.ts
├── pubspec.yaml
└── .env
```

---

## 📦 pubspec.yaml

```yaml
name: radiance_app
description: Radiance Coaching Center Management App

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

  # Supabase
  supabase_flutter: ^2.5.0

  # Firebase (Notifications only)
  firebase_core: ^3.4.0
  firebase_messaging: ^15.1.0
  flutter_local_notifications: ^17.2.0

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.2.0

  # PDF
  pdf: ^3.10.8
  printing: ^5.13.1
  path_provider: ^2.1.3

  # HTTP (SMS API)
  dio: ^5.6.0

  # Local Storage
  hive_flutter: ^1.1.0
  shared_preferences: ^2.3.1

  # Charts
  fl_chart: ^0.68.0

  # Video
  youtube_player_flutter: ^9.1.1
  video_player: ^2.9.1

  # Image
  image_picker: ^1.1.2
  cached_network_image: ^3.4.0

  # PDF Viewer
  flutter_pdfview: ^1.3.2

  # LaTeX / Math rendering
  flutter_math_fork: ^0.7.2

  # Utilities
  intl: ^0.19.0
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10+1
  url_launcher: ^6.3.0
  share_plus: ^9.0.0
  permission_handler: ^11.3.1
  connectivity_plus: ^6.0.5
  uuid: ^4.4.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.11
  flutter_lints: ^4.0.0
```

---

## 🗄️ Database Tables (Quick Reference)

```
users               → auth + profile + FCM token + role
courses             → name, thumbnail, fee, active
subjects            → course-এর under-এ
chapters            → subject-এর under-এ
notes               → chapter-এর content (pdf/video/text)
enrollments         → student ↔ course link
payments            → paid records + voucher no
payment_dues        → auto-generated monthly dues
attendance_sessions → date + course
attendance_records  → session → student → present/absent
exams               → MCQ exam config
questions           → exam-এর questions
exam_submissions    → student answers + score
results             → calculated results + grade + rank
qbank_questions     → question bank (chapter-wise)
qbank_bookmarks     → student saved questions
notifications       → in-app notifications
community_groups    → course-wise groups
community_messages  → chat messages
complaints          → student tickets
home_content        → CMS (banners, notices)
suggestions         → study tips
```

---

## 🚀 Play Store Deployment

```bash
# Build release AAB
flutter build appbundle --release

# Output:
# build/app/outputs/bundle/release/app-release.aab
```

**Play Store-এ লাগবে:**
- App icon: 512×512 PNG
- Feature graphic: 1024×500 PNG
- Screenshots: minimum 2
- Privacy Policy URL (student data collect করা হচ্ছে)
- One-time $25 developer fee

---

## 🌐 Admin Web Build (Admin + Public Payment)

```bash
# Admin/public-only web deployment flavor
flutter build web --release --dart-define=WEB_ADMIN_ONLY=true
```

**Route behavior in this flavor:**
- Keep: `/`, `/home`, `/login`, `/admin/*`, `/public/payment`
- Block: `/student/*`, `/teacher/*` (redirect to login)

---

## 💰 Monthly Cost

| Service | Cost |
|---|---|
| Supabase (Free tier) | $0 — শুরুতে যথেষ্ট |
| Supabase (Pro — 100+ students) | $25/month |
| Firebase FCM | **Free forever** |
| SSL Wireless SMS | ~৳0.35/SMS |
| Play Store | $25 one-time |
