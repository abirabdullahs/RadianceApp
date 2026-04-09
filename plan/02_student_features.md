# 🎓 STUDENT PANEL — Detailed Feature Documentation
## Radiance Coaching Center App (Flutter + Supabase)

---

## 📱 App Entry Flow

```
App Open
  ↓
Splash Screen (2s, Radiance logo + animation)
  ↓
Check: Supabase session exists?
  ├── Yes → Check role → Student Dashboard
  └── No  → Public Home Page
              ↓
          [Login / Sign Up]
              ↓
          Phone → OTP (SMS)
              ↓
          Student Dashboard
```

---

## 🏠 1. Public Home Page (No Login Required)

### Purpose
App install করার পর যে কেউ দেখতে পাবে। Coaching center-এর marketing page।

### Sections (Scrollable):

**1. Banner Slider (auto-scroll, 3s interval)**
- Admin uploaded promotional images
- Dots indicator at bottom
- Tap → course detail or notice

**2. Courses Available**
- Horizontal scrollable course cards
- Card: Thumbnail, Name, ৳Fee/month
- "ভর্তি হোন" button → Login screen redirect

**3. Notice Board**
- Latest 5 notices (title + date)
- "সব দেখুন" → full list

**4. Marketing / Achievement Section**
- Teacher intro text + photo
- Student success stories
- Result statistics ("HSC 2024-এ A+ পেয়েছে ৩২ জন শিক্ষার্থী")

**5. Contact Section**
- Phone number (tap to call)
- Address
- Google Maps "পথ দেখুন" button (url_launcher)
- Facebook, YouTube icon buttons

**Fixed Bottom Bar:**
```
[  লগইন করুন  ]  [  নতুন অ্যাকাউন্ট  ]
```

---

## 🔐 2. Login & Sign Up

### 2.1 Login Screen
```
Radiance 🌟
কোচিং সেন্টার

┌──────────────────────────┐
│ 📱 ০১XXXXXXXXX           │
└──────────────────────────┘
         [OTP পাঠাও]

OTP পায়নি? পুনরায় পাঠাও (00:45)
```

- Phone number input (BD format: 01XXXXXXXXX)
- OTP 6-digit input (auto-focus, auto-submit when 6 digits filled)
- OTP valid: 5 minutes
- Resend OTP countdown: 60 seconds
- Max 3 wrong OTP → 10 min cooldown

### 2.2 Sign Up Screen
- Admin manually student add করে → student-এর phone-এ invite SMS যায়
- Student first login করলে profile completion screen দেখায়
- Profile completion: Photo, Guardian phone (optional), Address (optional)

### 2.3 First Login — Profile Setup
- Profile photo upload (optional)
- Guardian phone number
- "সম্পন্ন করুন" → Dashboard

---

## 🏡 3. Student Dashboard (Home)

### Header:
```
🌟 Radiance
Good morning, Rahim! 🙏    [🔔3]
HSC Biology Batch · April 2025
```

### Quick Stats Row:
```
┌──────────┐ ┌──────────┐ ┌──────────┐
│ 📅 উপস্থিতি│ │ 📝 রেজাল্ট │ │ 💳 বকেয়া  │
│   83%    │ │   A+    │ │ ৳1,500  │
└──────────┘ └──────────┘ └──────────┘
```

### Upcoming Events Card:
```
🗓️ আসছে...
• Chemistry MCQ Exam — ১০ এপ্রিল, বিকাল ৩টা
• Physics Chapter 4 Notes যোগ হয়েছে
• Payment Due: এপ্রিল মাস
```

### Daily Suggestion Card:
- "আজকের পরামর্শ" — short study tip

### Recent Community Activity:
- Last 2-3 group messages preview

---

## 📚 4. My Courses

### 4.1 Course List
- GridView (2 columns) — Enrolled course cards
- Card: Thumbnail, Name, Enrolled date, Progress bar (notes read %)
- Tap → Course Detail

### 4.2 Course Detail Screen

**Header:** Course thumbnail + Name + Description

**Stats Row:**
- Subjects count | Chapters count | Total notes

**Tabs:**
| Tab | Content |
|---|---|
| 📖 পাঠ্যক্রম | Subject → Chapter → Notes tree |
| 📝 পরীক্ষা | Exams list for this course |
| 📊 রেজাল্ট | My results for this course |
| 👥 গ্রুপ | Community group chat |

---

## 📖 5. Class Notes (Study Material)

### Navigation:
```
My Courses → Course → Subject list
  → Chapter list → Notes list → Note viewer
```

### Subject Screen:
- ExpansionTile per subject
- Inside: Chapter list
- Chapter tap → Notes for that chapter

### Notes List (per chapter):
- ListTile: Icon (by type) + Title + Duration/Size + New badge
- Icons: 📄 PDF, 🎬 Video, 📝 Text, 🖼️ Image, 🔗 Link
- "নতুন" badge (last 7 days)
- ⬇️ Download icon (PDF-এর জন্য)
- ⭐ Bookmark

### Note Viewer (by type):

**PDF:**
- flutter_pdfview in-app viewer
- Page counter, zoom support
- Download to device button

**Text/HTML:**
- Rendered with flutter_html or custom widget
- Math: flutter_math_fork (KaTeX)
- Font size adjustment

**Video (YouTube):**
- youtube_player_flutter
- Full screen support
- Playback speed (0.75x, 1x, 1.25x, 1.5x, 2x)

**Image:**
- InteractiveViewer (pinch to zoom, pan)
- Download button

**External Link:**
- url_launcher → open in browser

### Offline Downloads:
- Downloaded notes list (path_provider)
- Storage used indicator
- Swipe to delete download

---

## 📅 6. My Attendance

### 6.1 Attendance Calendar View:
```
◀ মার্চ ২০২৫                    এপ্রিল ২০২৫ ▶

রবি  সোম  মঙ্গল  বুধ  বৃহ  শুক্র  শনি
       ✅    ✅    ❌    ✅   ✅
 ✅    ❌    ✅    ✅    ✅
```
- 🟢 ✅ Present | 🔴 ❌ Absent | ⚪ No class

**Legend + Stats Card:**
```
📊 এপ্রিল ২০২৫
মোট ক্লাস: ১৮ | উপস্থিত: ১৫ | অনুপস্থিত: ৩
উপস্থিতির হার: ৮৩.৩% ✅ নিয়মিত
```

### 6.2 Warning State:
```
⚠️ সতর্কতা!
তোমার উপস্থিতি ৭৫%-এর নিচে।
অনুগ্রহ করে নিয়মিত ক্লাসে আসো।
```

### 6.3 Course Filter:
- Multiple course-এ enrolled থাকলে → course switcher chip row

---

## 💳 7. Payment & Due

### 7.1 Payment Status Screen:

**Current Month Card:**
```
┌────────────────────────────────────┐
│ এপ্রিল ২০২৫ — HSC Biology Batch    │
│                                    │
│ ৳1,500/-          ❌ বকেয়া          │
│                                    │
│ পেমেন্ট করুন:                        │
│ bKash: 01711-XXXXXX               │
│ Nagad: 01711-XXXXXX               │
└────────────────────────────────────┘
```

**Paid Card (green):**
```
✅ মার্চ ২০২৫ — পরিশোধিত
৳1,500/- | ০৫ মার্চ ২০২৫ | Cash
[ভাউচার দেখুন 📄]
```

### 7.2 Payment History:
- ListView — Month, Amount, Status (color-coded), Date
- Tap paid row → View/Download Voucher
- Filter: All / Paid / Due

### 7.3 Voucher View/Download:
- PDF preview in-app
- Download to phone
- Share (WhatsApp etc.)

---

## 📝 8. Exams (Online MCQ)

### 8.1 Exam List Screen:
**Tabs:** আসছে | চলছে | শেষ

**Upcoming Card:**
```
📝 Chemistry MCQ — Chapter 5
📚 HSC Biology Batch
📅 ১০ এপ্রিল ২০২৫, বিকাল ৩:০০ টা
⏱ ৩০ মিনিট | ৩০টি প্রশ্ন
[⏰ 1 দিন 4 ঘণ্টা বাকি]
```

**Ended Card:**
```
✅ Physics MCQ — March
Score: 24/30 | Grade: A | Rank: #3
[রেজাল্ট দেখুন]
```

### 8.2 Exam Instructions Screen:
- Exam title, subject
- Start time, Duration
- Total questions, Total marks
- Negative marking (-0.25/wrong)
- Instructions text (admin entered)
- Countdown timer (if scheduled)
- "পরীক্ষা শুরু করুন" button (active during window only)

### 8.3 Exam Taking Screen:

**Layout:**
```
Chemistry MCQ · Chapter 5            ⏱ 28:45

━━━━━━━━━━━━━━━━━━━━━━━  5/30

মোলার ঘনত্বের একক কোনটি?

  ○  (A) g/L
  ●  (B) mol/L          ← Selected (filled circle)
  ○  (C) g/mol
  ○  (D) mol/g

[⚑ সন্দেহজনক]   [প্রশ্ন তালিকা 🗂️]

[◀ আগের]                    [পরের ▶]
```

**Features:**
- Timer: CountdownTimer widget, turns red at < 5 min
- Question Navigator (bottom sheet): 6-column grid
  - ✅ Answered | ⬜ Not visited | 🔵 Current | ⚑ Flagged
- "Mark for Review" → ⚑ flag, revisit later
- Swipe left/right to change question
- Auto-submit when time expires (with 10s warning dialog)
- Screen exit → AlertDialog: "পরীক্ষা ছেড়ে যাবেন?"
- **Offline safety:** answers Hive local storage-এ save, internet reconnect-এ sync
- LaTeX rendering: flutter_math_fork
- Image questions: CachedNetworkImage

### 8.4 Submit Confirmation:
```
পরীক্ষা জমা দেবেন?

উত্তর দেওয়া: ২৮/৩০
সন্দেহজনক: ২টি
উত্তর দেওয়া হয়নি: ২টি

[আরেকবার দেখি]  [জমা দাও ✅]
```

### 8.5 Result Screen (Immediate):
```
🎉 পরীক্ষা সম্পন্ন!

Score: 24/30 (80%)
Grade: A
Rank: #3 (৪৭ জনের মধ্যে)

✅ সঠিক: ২৪   ❌ ভুল: ৪   ○ বাদ: ২
নেতিবাচক: -১.০০

সময় লেগেছে: ৩১ মিনিট ২০ সেকেন্ড

[উত্তর দেখুন 📋]      [হোমে যাও 🏠]
```

### 8.6 Answer Review (after publish):
- প্রতিটি question:
  - তোমার উত্তর (green if correct, red if wrong)
  - সঠিক উত্তর
  - Explanation (if available)

---

## 📊 9. Results

### 9.1 All Results List:
- ListTile: Exam name, Subject, Date, Score, Grade chip, Rank
- Filter: Course | Subject | Date range

### 9.2 Result Detail:
- Exam info header
- Score card: Score / Total | Grade | Rank | Pass/Fail
- "Class average vs You" — horizontal bar comparison (fl_chart)
- Download Result Card PDF

### 9.3 Performance Analytics:
- Subject-wise average (RadarChart — fl_chart)
- Last 6 exams score trend (LineChart)
- Strong Subjects: 🟢 | Weak Subjects: 🔴

---

## 💬 10. Community (Batch Group Chat)

### 10.1 Group List:
- Enrolled courses প্রতিটির জন্য একটি group
- Unread message badge
- Last message preview + time

### 10.2 Chat Screen:
```
HSC Biology Batch 2025              👥 47
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📌 [Admin] Chapter 5 er PDF upload holo! — Pinned

[08 Apr]─────────────────────────

Admin 👑  3:15 PM
Chapter 5 er notes check koro.
Supabase e upload diye dilam.

Rahim  3:17 PM
Thank you Sir! 🙏

         You  3:18 PM
Got it! Reading now 📖         ✓✓

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[📎]  [Type a message...    ]  [➤]
```

**Features:**
- Supabase Realtime → instant messages
- Text, Image, File (PDF) support
- Reply to specific message (long press → Reply)
- Emoji reactions (long press message)
- Admin messages: Crown icon + different bubble color
- Pinned messages (admin sets)
- Member list: "👥 47 members"
- Report message (flag icon)
- Images: full-screen viewer on tap

**Restrictions (Student):**
- Cannot create groups
- Cannot delete others' messages
- Can delete own message (within 5 min)

---

## 🧠 11. Question Bank (Q-Bank)

### 11.1 Browse Screen:
- Subject list (your enrolled courses-এর subjects)
- Tap subject → Chapter list → Questions

### 11.2 Question List:
- ListTile: Question preview (first 80 chars), Difficulty chip, Source
- Filter chips: Easy | Medium | Hard | MCQ | Short | Board | Admission
- Search bar (full-text)
- ⭐ Bookmark icon per question

### 11.3 Question Detail:
```
┌──────────────────────────────────┐
│ 📚 Chemistry · Atomic Structure  │
│ 🟡 Medium · Board 2022           │
├──────────────────────────────────┤
│ পরমাণুর নিউক্লিয়াসে কী থাকে?     │
│                                  │
│ ○ (A) ইলেকট্রন ও প্রোটন           │
│ ● (B) প্রোটন ও নিউট্রন  ← Correct │
│ ○ (C) ইলেকট্রন ও নিউট্রন          │
│ ○ (D) শুধু প্রোটন                 │
│                                  │
│ [উত্তর দেখাও 👁️]  [⭐ সংরক্ষণ]   │
└──────────────────────────────────┘
```

### 11.4 Practice Mode:
- Chapter/topic select → Practice session start
- One question at a time
- Answer select → immediate feedback (green/red)
- Explanation show
- Final: "২০টির মধ্যে ১৫টি সঠিক (৭৫%)"

### 11.5 Bookmarks:
- Saved questions list
- Organized by subject
- Quick practice from bookmarks

---

## 💡 12. Suggestions

### Daily Tip Card (Home + dedicated screen):
- Title + Content (text/image/short video)
- ❤️ Like | 🔖 Save | 📤 Share (auto-generated card image)

### Categories:
- 📚 পড়ার কৌশল — Study tips
- ⏰ সময় ব্যবস্থাপনা — Time management
- 🧠 পরীক্ষার কৌশল — Exam strategy
- 💪 অনুপ্রেরণা — Motivation

### Saved Suggestions:
- Bookmarked suggestions list

---

## 🎬 13. Video Content

### Video Library:
- Grouped by Subject → Chapter
- Thumbnail (YouTube thumbnail API) + Title + Duration
- Unwatch / Watched indicator

### Video Player Screen:
- youtube_player_flutter
- Full screen (landscape) support
- Playback speed controller (0.75x, 1x, 1.25x, 1.5x, 2x)
- While watching: note-taking side panel (notes save করা যাবে)
- Progress: auto-mark as watched when 90% complete
- Share video link button

---

## 🔔 14. Notifications

### 14.1 Notification Center:
- Grouped by date: "আজকে", "গতকাল", "এই সপ্তাহ"
- প্রতিটি item: Icon (by type) + Title + Body preview + Time
- Tap → Detail + action (Go to Exam, View Result, etc.)
- Swipe to dismiss

### Notification Types:
| Type | Icon | Color |
|---|---|---|
| নতুন পরীক্ষা | 📝 | Blue |
| নতুন স্টাডি মেটেরিয়াল | 📄 | Green |
| পেমেন্ট বকেয়া | 💳 | Orange |
| রেজাল্ট প্রকাশিত | 📊 | Purple |
| সাধারণ ঘোষণা | 📢 | Grey |
| উপস্থিতি সতর্কতা | ⚠️ | Red |

### 14.2 Push Notifications:
- FCM background/foreground handler
- Tap notification → deep link to relevant screen (GoRouter)
- flutter_local_notifications for foreground display

### 14.3 Notification Settings:
- Per-type toggle (SharedPreferences)
- Quiet hours: 10 PM – 7 AM

---

## 🆘 15. Complaints & Feedback

### Submit Complaint:
| Field | Widget |
|---|---|
| Category | DropdownButton (Academic/Payment/Technical/Other) |
| Subject | TextFormField |
| Description | TextFormField (5 lines) |
| Attachment | FilePicker (image optional) |

After submit: Ticket No. generated (RCC-TICKET-001), confirmation notification

### My Complaints List:
- ListTile: Ticket no., Subject, Date, Status chip
- Status: 🟡 Pending | 🔵 পর্যালোচনায় | 🟢 সমাধান হয়েছে | 🔴 বাতিল
- Tap → Detail: full conversation thread (admin reply দেখা + follow-up add)

---

## 👤 16. Student Profile

### Profile Screen:
```
     [📷 Avatar]
   Rahim Uddin রহিম উদ্দিন
   ID: RCC-2025-012
   📱 01711-XXXXXX
   🎓 HSC 2025 Batch
   
   [✏️ প্রোফাইল সম্পাদনা]
```

### Editable (self):
- Profile photo (ImagePicker → Supabase Storage)
- Guardian phone
- Address

### Read-only (admin set):
- Name, ID, DOB, enrolled courses

### Account:
- পাসওয়ার্ড পরিবর্তন (OTP re-verify)
- অ্যাকাউন্ট মুছুন (request → admin approval)
- লগআউট

---

## ⚙️ 17. App Settings

| Setting | Type |
|---|---|
| ভাষা | Toggle: বাংলা / English |
| থিম | Radio: Light / Dark / System |
| ফন্ট সাইজ | Slider: Small / Medium / Large |
| নোটিফিকেশন | Per-type switch |
| ডাউনলোড ফাইল | Storage used + Clear button |
| About | Version, Privacy Policy, Terms |
| Help | FAQ accordion |

---

## 🎨 Student App UI Notes (Flutter)

### Bottom Navigation (5 tabs):
```
🏠 হোম | 📚 কোর্স | 💬 গ্রুপ | 🔔 নোটিফ | 👤 আমি
```

### Design System:
```dart
// Colors
primary:    Color(0xFF1A3C6E)   // Deep Navy
accent:     Color(0xFFF5A623)   // Golden
surface:    Color(0xFFF8F9FA)   // Light bg
darkBg:     Color(0xFF0F1923)   // Dark mode bg

// Fonts
Bengali:    GoogleFonts.hindSiliguri()
English:    GoogleFonts.nunito()

// Card radius: 12px
// Padding standard: 16px
// Shadow: BoxShadow(blurRadius: 8, opacity: 0.08)
```

### UX Patterns:
- Skeleton loading (shimmer) — no spinner
- Pull-to-refresh everywhere
- Empty state: illustrated SVG + helpful Bengali text
- Error state: retry button
- Offline banner: "ইন্টারনেট সংযোগ নেই"
- Haptic feedback on button taps
