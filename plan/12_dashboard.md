# 🏠 DASHBOARD — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)
### Admin Dashboard + Student Dashboard

---

# 👨‍💼 ADMIN DASHBOARD

Admin login করলে এই screen-টি হবে সব কিছুর কেন্দ্র।  
এখান থেকে সব module-এ directly যাওয়া যাবে।

---

## Layout Overview

```
┌─────────────────────────────────────────────────────────┐
│  HEADER                                                 │
│  🌟 Radiance Admin            [🔔 5]  [👤 Admin]        │
├─────────────────────────────────────────────────────────┤
│  GREETING                                               │
│  Good Morning, Admin! 👋                                │
│  ০৮ এপ্রিল ২০২৫, সোমবার                                │
├─────────────────────────────────────────────────────────┤
│  QUICK STATS ROW (Scrollable)                           │
├─────────────────────────────────────────────────────────┤
│  QUICK ACTIONS GRID                                     │
├─────────────────────────────────────────────────────────┤
│  TODAY'S OVERVIEW                                       │
├─────────────────────────────────────────────────────────┤
│  CHARTS                                                 │
├─────────────────────────────────────────────────────────┤
│  RECENT ACTIVITY                                        │
└─────────────────────────────────────────────────────────┘

BOTTOM NAV:
[🏠 Dashboard] [👥 Students] [💳 Payments] [📅 Attendance] [☰ More]
```

---

## Section 1 — Header

```
┌─────────────────────────────────────────────────────────┐
│  🌟 Radiance                         [🔔 5]  [👤]       │
│     Coaching Center Admin Panel                         │
└─────────────────────────────────────────────────────────┘
```

- **[🔔 5]** → Notification center (5 unread)
- **[👤]** → Admin profile: নাম, ছবি, Logout button

---

## Section 2 — Greeting + Date

```
Good Morning, Admin! 👋
০৮ এপ্রিল ২০২৫, সোমবার
```

সময় অনুযায়ী greeting:
- 06–11 → Good Morning 🌅
- 12–17 → Good Afternoon ☀️
- 18–22 → Good Evening 🌆
- 22–06 → Good Night 🌙

---

## Section 3 — Quick Stats (Horizontal Scroll)

```
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ 👥 মোট       │ │ 📅 আজ উপস্থিতি│ │ 💰 এই মাস    │ │ 🔴 মোট বকেয়া │ │ 💬 Open Doubt│ │ 📝 Upcoming  │
│ শিক্ষার্থী   │ │              │ │ কালেকশন      │ │              │ │              │ │ পরীক্ষা      │
│    ৪৭ জন    │ │   ৩৮/৪৭ (81%)│ │  ৳ ৭১,৫০০   │ │  ৳ ১৮,৫০০   │ │    ১২টি      │ │     ৩টি      │
│             │ │              │ │              │ │              │ │              │ │              │
│ ↑ ৩ নতুন    │ │ 🟢 ভালো       │ │ আগের চেয়ে ↑ │ │ ১২ জনের     │ │ [দেখুন →]   │ │ [দেখুন →]   │
│ এই সপ্তাহে  │ │              │ │ ৮% বেশি     │ │              │ │              │ │              │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

প্রতিটি card tap করলে সেই module-এ যাবে।

---

## Section 4 — Quick Actions Grid (2×4)

```
┌────────────────────┐  ┌────────────────────┐
│   ➕ শিক্ষার্থী    │  │   💳 পেমেন্ট নাও   │
│   যোগ করুন        │  │                    │
└────────────────────┘  └────────────────────┘
┌────────────────────┐  ┌────────────────────┐
│   📅 উপস্থিতি     │  │   📝 পরীক্ষা তৈরি  │
│   শুরু করুন       │  │   করুন             │
└────────────────────┘  └────────────────────┘
┌────────────────────┐  ┌────────────────────┐
│   📖 নোট যোগ করুন │  │   💬 Doubt দেখুন   │
│                    │  │                    │
└────────────────────┘  └────────────────────┘
┌────────────────────┐  ┌────────────────────┐
│   📊 রিপোর্ট দেখুন │  │   📢 Notification  │
│                    │  │   পাঠান            │
└────────────────────┘  └────────────────────┘
```

প্রতিটি card-এ icon + label + primary color background।  
Tap করলে সরাসরি সেই screen-এ যাবে।

---

## Section 5 — Today's Overview

```
━━━ আজকের অবস্থা (০৮ এপ্রিল) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────────────────────┐
│ 📅 উপস্থিতি                                             │
│                                                          │
│ HSC Biology    ━━━━━━━━━━━━━━━━━━━░░░░  ৩৫/৪০  ✅ হয়েছে│
│ HSC Chemistry  ━━━━━━━━━━━━━━━━━░░░░░░  ২৮/৩৫  ✅ হয়েছে│
│ SSC Math       ░░░░░░░░░░░░░░░░░░░░░░░  —/৪৫   ⏳ হয়নি │
│                                                          │
│                             [📋 উপস্থিতি শুরু করুন →]   │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ 💳 আজকের পেমেন্ট (৫টি)                                  │
│                                                          │
│ ২:৩০ PM  রহিম উদ্দিন    মাসিক বেতন   ৳ ১,৫০০  Cash ✅  │
│ ১:১৫ PM  সাদিয়া ইসলাম  ভর্তি ফি     ৳ ৫০০    bKash✅  │
│ ১১:০০ AM তানভীর হোসেন   উপকরণ ফি    ৳ ৩০০    Cash ✅  │
│                                                          │
│ আজ মোট: ৳ ৭,৮০০         [সব দেখুন →]                   │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ 📝 আসছে পরীক্ষা                                          │
│                                                          │
│ 🌐 Chemistry MCQ — CH5   ১০ এপ্রিল, ৩টা  HSC Biology   │
│ 📋 Chemistry CQ — April  ১৫ এপ্রিল, ১০টা HSC Biology   │
│ 🌐 Physics MCQ — CH3     ১২ এপ্রিল, ৪টা  HSC Chem      │
│                                                          │
│                              [পরীক্ষা ব্যবস্থাপনা →]    │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ 💬 Unresolved Doubts (১২টি)                              │
│                                                          │
│ 🔴 রহিম   রসায়ন  মোলার ঘনত্র...   ১০ মি আগে           │
│ 🔵 সাদিয়া পদার্থ  নিউটনের ২য়...   ২ ঘণ্টা আগে         │
│ 🔴 করিম   গণিত   লগারিদম...        ৩ ঘণ্টা আগে         │
│                                                          │
│                                 [সব Doubts দেখুন →]     │
└──────────────────────────────────────────────────────────┘
```

---

## Section 6 — Charts

```
━━━ Analytics ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────────────────────┐
│ 💰 মাসিক কালেকশন (শেষ ৬ মাস)          [Course ▼]       │
│                                                          │
│  ৮০k ┤         ██                                       │
│  ৭০k ┤   ██    ██    ██                                 │
│  ৬০k ┤   ██    ██    ██    ██    ██                     │
│  ৫০k ┤   ██    ██    ██    ██    ██    ██               │
│       └───────────────────────────────────────          │
│        নভে  ডিসে  জানু  ফেব্রু মার্চ  এপ্রিল           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ 📅 উপস্থিতি Trend (শেষ ৩০ দিন)        [Course ▼]       │
│                                                          │
│ 100%┤    ╭─╮  ╭──╮                                      │
│  80%┤╭──╯  ╰─╯  ╰───╮  ╭─╮                             │
│  60%┤                ╰──╯  ╰──                          │
│      └──────────────────────────                        │
│       ১০মার্চ        ২৫মার্চ       ০৮এপ্রিল             │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ 👥 Course-wise শিক্ষার্থী বিতরণ                          │
│                                                          │
│   🔵 HSC Biology  ────────── ৪০ জন (৪৫%)               │
│   🟣 HSC Chemistry ──────── ৩৫ জন (৩৯%)                │
│   🟢 SSC Math ────── ১৪ জন (১৬%)                       │
│                                                          │
│   [Pie Chart — fl_chart]                                 │
└──────────────────────────────────────────────────────────┘
```

---

## Section 7 — Recent Activity Feed

```
━━━ সাম্প্রতিক কার্যক্রম ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💳  রহিম উদ্দিন — ৳ ১,৫০০ মাসিক বেতন (Cash)     ২ মি আগে
📅  HSC Biology উপস্থিতি শেষ — ৩৫/৪০ উপস্থিত    ৩০ মি আগে
👥  নতুন শিক্ষার্থী: নাজমুল হক (RCC-2025-048)     ১ ঘণ্টা আগে
📝  Chemistry MCQ CH5 Scheduled — ১০ এপ্রিল       ২ ঘণ্টা আগে
📊  Physics MCQ result published                   ৩ ঘণ্টা আগে
💳  সাদিয়া ইসলাম — ৳ ৫০০ ভর্তি ফি (bKash)       ৫ ঘণ্টা আগে
📖  রসায়ন অধ্যায় ৩ — নতুন PDF নোট যোগ          গতকাল
💬  করিম মিয়ার doubt solved — গণিত               গতকাল
                                                  [আরও →]
```

---

## Bottom Navigation (Admin)

```
┌──────────────────────────────────────────────────────────┐
│  [🏠 Dashboard] [👥 Students] [💳 Payments] [📅 Attend] [☰ More]│
└──────────────────────────────────────────────────────────┘
```

**[☰ More] tap করলে Drawer/Sheet খুলবে:**

```
━━━ সব Module ━━━━━━━━━━━━━━━━━━━━━━━━

📚 কোর্স ব্যবস্থাপনা
📖 ক্লাসনোট
📝 পরীক্ষা ব্যবস্থাপনা
📊 ফলাফল ব্যবস্থাপনা
💬 Doubt Solving
🧠 প্রশ্নব্যাংক
🔔 Notification পাঠান
📢 Home Page Content
📈 Reports & Analytics
⚙️ Settings

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Admin Profile
🚪 Logout
```

---

## Notification Center (Admin)

```
🔔 Notifications (৫টি অপঠিত)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴  করিম মিয়া নতুন Doubt জমা দিয়েছে     ১০ মি আগে  [দেখুন]
💳  রহিম উদ্দিন পেমেন্ট করেছে — ৳ ১,৫০০  ৩০ মি আগে
🔴  ৪ জন শিক্ষার্থীর উপস্থিতি ৭৫%-এর    ১ ঘণ্টা আগে [দেখুন]
    নিচে চলে গেছে
💬  সাদিয়া Doubt-এ reply করেছে            ২ ঘণ্টা আগে [দেখুন]
📊  Physics MCQ result publish ready       ৩ ঘণ্টা আগে [Publish]
```

---

# 🎓 STUDENT DASHBOARD

---

## Layout Overview

```
┌─────────────────────────────────────────────────────────┐
│  HEADER                                                 │
│  🌟 Radiance              [🔔 3]  [🔍]                  │
├─────────────────────────────────────────────────────────┤
│  GREETING + PROFILE CARD                                │
├─────────────────────────────────────────────────────────┤
│  ALERT BANNER (if due/warning)                          │
├─────────────────────────────────────────────────────────┤
│  QUICK STATS ROW                                        │
├─────────────────────────────────────────────────────────┤
│  UPCOMING EVENTS                                        │
├─────────────────────────────────────────────────────────┤
│  MY COURSES                                             │
├─────────────────────────────────────────────────────────┤
│  DAILY SUGGESTION                                       │
├─────────────────────────────────────────────────────────┤
│  RECENT ACTIVITY                                        │
└─────────────────────────────────────────────────────────┘

BOTTOM NAV:
[🏠 Home] [📚 Courses] [💬 Community] [🔔 Notifications] [👤 Profile]
```

---

## Section 1 — Header

```
┌─────────────────────────────────────────────────────────┐
│  🌟 Radiance                         [🔔 3]  [🔍]       │
└─────────────────────────────────────────────────────────┘
```

- **[🔔 3]** → Notification center
- **[🔍]** → Global search (notes, exams, q-bank)

---

## Section 2 — Greeting + Profile Card

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   [👤 Photo]   Good Morning, রহিম! 👋                  │
│                RCC-2025-012                             │
│                HSC Biology Batch 2025                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Section 3 — Alert Banner (Conditional)

পেমেন্ট বকেয়া থাকলে:
```
┌─────────────────────────────────────────────────────────┐
│ 🔴  এপ্রিল মাসের বেতন ৳ ১,৫০০ বকেয়া আছে।              │
│     Due: ১৫ এপ্রিল ২০২৫                  [বিস্তারিত →] │
└─────────────────────────────────────────────────────────┘
```

উপস্থিতি কম হলে:
```
┌─────────────────────────────────────────────────────────┐
│ ⚠️  তোমার উপস্থিতি ৬৮% — ৭৫%-এর নিচে।                 │
│     নিয়মিত ক্লাসে আসো।                   [দেখুন →]     │
└─────────────────────────────────────────────────────────┘
```

Unread doubt reply:
```
┌─────────────────────────────────────────────────────────┐
│ 💬  তোমার "মোলার ঘনত্র" doubt-এ স্যার reply করেছেন।   │
│                                           [দেখুন →]     │
└─────────────────────────────────────────────────────────┘
```

Multiple alert থাকলে → swipeable banner (PageView)

---

## Section 4 — Quick Stats (Horizontal Scroll)

```
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ 📅 উপস্থিতি  │ │ 📊 শেষ Result│ │ 💳 পেমেন্ট   │ │ 💬 Doubt     │
│              │ │              │ │ স্ট্যাটাস    │ │              │
│ এপ্রিল ২০২৫ │ │ Chemistry    │ │              │ │              │
│    ১৫/১৮    │ │  MCQ CH5     │ │ এপ্রিল       │ │ ৩টি open    │
│    ৮৩%      │ │  ২৭/৩০  A+  │ │ ✅ পরিশোধিত  │ │ ১টি replied  │
│ 🟢 নিয়মিত   │ │  Rank: #2   │ │              │ │              │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

Tap করলে সেই section-এ যাবে।

---

## Section 5 — Upcoming Events

```
━━━ আসছে ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────┐
│ 📝  🌐 Chemistry MCQ — CH5                              │
│     ১০ এপ্রিল ২০২৫, বিকাল ৩:০০ টা  |  ৩০ মিনিট       │
│     ⏰ ২ দিন ৪ ঘণ্টা বাকি                               │
│                                       [বিস্তারিত →]    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 📋  Offline Chemistry CQ — April                        │
│     ১৫ এপ্রিল ২০২৫, সকাল ১০:০০ টা  |  Classroom 1     │
│     ⏰ ৭ দিন বাকি                                        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 💳  এপ্রিল মাসের বেতন Due                               │
│     Due: ১৫ এপ্রিল ২০২৫  |  ৳ ১,৫০০                   │
│     bKash: 01711-XXXXXX                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Section 6 — My Courses (Enrolled)

```
━━━ আমার কোর্স ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────┐ ┌──────────────────────────────┐
│ [Thumbnail]                  │ │ [Thumbnail]                  │
│ HSC Biology Batch 2025       │ │ HSC Chemistry Batch          │
│ ৪০ জন  |  ৬ বিষয়           │ │ ৩৫ জন  |  ৪ বিষয়           │
│ নোট পড়া: ৩২%               │ │ নোট পড়া: ১৮%               │
│ ━━━━━━━━━━━░░░░░░  ৩২%      │ │ ━━━░░░░░░░░░░░░░  ১৮%      │
│ [→ কোর্সে যাও]               │ │ [→ কোর্সে যাও]               │
└──────────────────────────────┘ └──────────────────────────────┘
```

---

## Section 7 — Daily Suggestion

```
━━━ আজকের পরামর্শ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────┐
│  💡  পরীক্ষার কৌশল                                       │
│                                                         │
│  "MCQ পরীক্ষায় আগে সহজ প্রশ্নগুলো দাও,                │
│   তারপর কঠিনগুলোতে সময় দাও।                            │
│   সন্দেহ হলে ছেড়ে দাও — নেগেটিভ মার্কিং               │
│   তোমার বিপদ করতে পারে।"                               │
│                                                         │
│  [❤️ ৩৪]                      [📤 শেয়ার]               │
└─────────────────────────────────────────────────────────┘
```

---

## Section 8 — Recent Activity

```
━━━ সাম্প্রতিক ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄  রসায়ন অধ্যায় ৩ — নতুন PDF নোট         ২ ঘণ্টা আগে  [দেখুন]
📊  Physics MCQ CH3 result প্রকাশিত          ৩ ঘণ্টা আগে  [দেখুন]
💬  Doubt-এ স্যার reply করেছেন               ৫ ঘণ্টা আগে  [দেখুন]
💳  এপ্রিল বেতন পরিশোধিত — ৳ ১,৫০০          গতকাল        [ভাউচার]
```

---

## Bottom Navigation (Student)

```
┌──────────────────────────────────────────────────────────┐
│  [🏠 Home]  [📚 Courses]  [💬 Community]  [🔔 Notif]  [👤 Profile] │
└──────────────────────────────────────────────────────────┘
```

**[👤 Profile] tap করলে:**

```
━━━ Profile ━━━━━━━━━━━━━━━━━━━━━━━━━━

[Photo]  রহিম উদ্দিন
         RCC-2025-012
         HSC Biology Batch

━━━ আমার সেকশন ━━━━━━━━━━━━━━━━━━━━━━

📅 আমার উপস্থিতি
💳 পেমেন্ট ও বকেয়া
📊 আমার ফলাফল
🧠 প্রশ্নব্যাংক
💬 Doubt Solving
⭐ Bookmarks
📥 Download করা নোট
🆘 Complain করুন
⚙️ Settings

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💬 Doubt Stats: ২৩ জমা | ১৯ Solved
🚪 Logout
```

---

## Notification Center (Student)

```
🔔 Notifications (৩টি অপঠিত)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝  Chemistry MCQ — ১০ এপ্রিল নিশ্চিত করা   ২ ঘণ্টা আগে  [দেখুন]
💬  তোমার Doubt-এ reply এসেছে               ৫ ঘণ্টা আগে  [দেখুন]
📄  রসায়ন অধ্যায় ৩ নতুন নোট যোগ হয়েছে     গতকাল         [দেখুন]
💳  এপ্রিল পেমেন্ট গৃহীত — ৳ ১,৫০০          গতকাল         [ভাউচার]
📊  Physics MCQ result প্রকাশিত — A, #5      ২ দিন আগে    [দেখুন]
```

---

# 🔧 FLUTTER IMPLEMENTATION

## Admin Dashboard Data Loading

```dart
// AdminDashboardNotifier — load all stats in parallel
@riverpod
class AdminDashboardNotifier extends _$AdminDashboardNotifier {

  @override
  Future<AdminDashboardData> build() async {
    final results = await Future.wait([
      _getStudentCount(),
      _getTodayAttendance(),
      _getMonthlyRevenue(),
      _getTotalDue(),
      _getOpenDoubtsCount(),
      _getUpcomingExams(),
      _getTodayPayments(),
      _getRecentActivity(),
      _getMonthlyRevenueChart(),
      _getAttendanceTrend(),
      _getCourseDistribution(),
    ]);

    return AdminDashboardData(
      totalStudents:     results[0] as int,
      todayAttendance:   results[1] as AttendanceSummary,
      monthlyRevenue:    results[2] as double,
      totalDue:          results[3] as double,
      openDoubts:        results[4] as int,
      upcomingExams:     results[5] as List<Exam>,
      todayPayments:     results[6] as List<Payment>,
      recentActivity:    results[7] as List<ActivityItem>,
      revenueChart:      results[8] as List<ChartPoint>,
      attendanceTrend:   results[9] as List<ChartPoint>,
      courseDistribution:results[10] as List<PieSlice>,
    );
  }
}
```

## Student Dashboard Data Loading

```dart
@riverpod
class StudentDashboardNotifier extends _$StudentDashboardNotifier {

  @override
  Future<StudentDashboardData> build() async {
    final studentId = ref.watch(currentUserProvider).value!.id;

    final results = await Future.wait([
      _getThisMonthAttendance(studentId),
      _getLatestResult(studentId),
      _getCurrentMonthPaymentStatus(studentId),
      _getOpenDoubts(studentId),
      _getUpcomingExams(studentId),
      _getEnrolledCourses(studentId),
      _getAlerts(studentId),          // due + attendance warning + doubt reply
      _getDailySuggestion(),
      _getRecentActivity(studentId),
    ]);

    return StudentDashboardData(
      attendance:       results[0] as AttendanceSummary,
      latestResult:     results[1] as ResultSummary?,
      paymentStatus:    results[2] as PaymentStatus,
      openDoubts:       results[3] as int,
      upcomingExams:    results[4] as List<Exam>,
      enrolledCourses:  results[5] as List<Course>,
      alerts:           results[6] as List<DashboardAlert>,
      suggestion:       results[7] as Suggestion,
      recentActivity:   results[8] as List<ActivityItem>,
    );
  }
}
```

## Alert Banner Widget

```dart
class AlertBanner extends StatelessWidget {
  final List<DashboardAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    if (alerts.length == 1) return _buildSingleBanner(alerts.first);

    // Multiple alerts: PageView with dots
    return SizedBox(
      height: 64,
      child: PageView.builder(
        itemCount: alerts.length,
        itemBuilder: (_, i) => _buildSingleBanner(alerts[i]),
      ),
    );
  }

  Widget _buildSingleBanner(DashboardAlert alert) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: alert.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alert.color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Text(alert.icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(alert.message,
            style: TextStyle(color: alert.color, fontSize: 13))),
        TextButton(onPressed: alert.onTap, child: const Text('দেখুন →')),
      ]),
    );
  }
}
```

## Quick Action Card Widget

```dart
class QuickActionCard extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: GoogleFonts.hindSiliguri().fontFamily,
                )),
          ],
        ),
      ),
    );
  }
}
```

---

# 📊 KEY SQL QUERIES

```sql
-- Admin: today's attendance overview (per course)
SELECT
  c.name,
  COUNT(ar.id) FILTER (WHERE ar.status = 'present') AS present,
  COUNT(e.student_id) AS total_enrolled,
  ats.is_completed
FROM courses c
LEFT JOIN enrollments e ON e.course_id = c.id AND e.status = 'active'
LEFT JOIN attendance_sessions ats ON ats.course_id = c.id AND ats.session_date = CURRENT_DATE
LEFT JOIN attendance_records ar ON ar.session_id = ats.id
GROUP BY c.id, c.name, ats.is_completed
ORDER BY c.name;

-- Admin: today's payment total
SELECT SUM(amount_paid) AS today_total, COUNT(*) AS count
FROM payment_ledger
WHERE DATE(paid_at) = CURRENT_DATE;

-- Admin: recent activity (union of actions)
SELECT 'payment' AS type, u.full_name_bn, pl.amount_paid AS value,
       pl.paid_at AS ts
FROM payment_ledger pl JOIN users u ON pl.student_id = u.id
UNION ALL
SELECT 'student_added', u.full_name_bn, NULL, u.created_at
FROM users u WHERE u.role = 'student'
UNION ALL
SELECT 'doubt_open', u.full_name_bn, NULL, d.created_at
FROM doubts d JOIN users u ON d.student_id = u.id
ORDER BY ts DESC LIMIT 10;

-- Student: current month attendance
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE ar.status = 'present') AS present,
  ROUND(COUNT(*) FILTER (WHERE ar.status = 'present') * 100.0 / COUNT(*), 1) AS pct
FROM attendance_records ar
JOIN attendance_sessions ats ON ar.session_id = ats.id
WHERE ar.student_id = 'STUDENT_UUID'
  AND ats.course_id = 'COURSE_UUID'
  AND DATE_TRUNC('month', ats.session_date) = DATE_TRUNC('month', CURRENT_DATE);

-- Student: alerts (due + low attendance)
SELECT 'due' AS type, ps.amount, ps.for_month, ps.due_date
FROM payment_schedule ps
WHERE ps.student_id = 'STUDENT_UUID' AND ps.status IN ('pending','partial')
UNION ALL
SELECT 'attendance', NULL, NULL, NULL
WHERE (
  SELECT ROUND(COUNT(*) FILTER (WHERE ar.status='present') * 100.0 / NULLIF(COUNT(*),0), 1)
  FROM attendance_records ar
  JOIN attendance_sessions ats ON ar.session_id = ats.id
  WHERE ar.student_id = 'STUDENT_UUID'
    AND DATE_TRUNC('month', ats.session_date) = DATE_TRUNC('month', CURRENT_DATE)
) < 75;
```

---

# ✅ FEATURE CHECKLIST

## Admin Dashboard:
- [ ] Greeting (time-based)
- [ ] 6 Quick Stat cards (students, attendance, revenue, due, doubts, exams)
- [ ] 8 Quick Action cards (all modules directly accessible)
- [ ] Today's attendance per course (completed/not)
- [ ] Today's payment list (last 5)
- [ ] Upcoming exams (online + offline)
- [ ] Open doubts preview (last 3)
- [ ] Monthly revenue bar chart (6 months)
- [ ] Attendance trend line chart (30 days)
- [ ] Course distribution pie chart
- [ ] Recent activity feed
- [ ] Notification center (admin-specific)
- [ ] Bottom nav (Dashboard, Students, Payments, Attendance, More)
- [ ] More drawer (all modules listed)

## Student Dashboard:
- [ ] Greeting (time-based) + profile card
- [ ] Conditional alert banners (due / attendance warning / doubt reply)
- [ ] Multiple alerts → swipeable banner
- [ ] 4 Quick Stat cards (attendance, result, payment, doubts)
- [ ] Upcoming events (exams + due)
- [ ] Enrolled courses (with notes progress bar)
- [ ] Daily suggestion card
- [ ] Recent activity feed
- [ ] Notification center (student-specific)
- [ ] Bottom nav (Home, Courses, Community, Notifications, Profile)
- [ ] Profile sheet (all student modules listed)
