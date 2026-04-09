# 👨‍💼 ADMIN PANEL — Detailed Feature Documentation
## Radiance Coaching Center App (Flutter + Supabase)

---

## 🔐 Admin Login Flow

```
App Open → Public Home
    ↓ [Login button]
Phone Number input
    ↓
OTP via SMS (Supabase Auth)
    ↓
Role check: if role == 'admin'
    ↓
Admin Dashboard
```

Admin-এর role Supabase-এ manually set করা থাকবে।  
Admin sign-up publicly available থাকবে না।

---

## 🏠 1. Admin Dashboard

### Layout
- **AppBar:** Radiance logo + Admin avatar + Notification bell (badge count)
- **Greeting:** "Good morning, Admin! — আজকে ০৮ এপ্রিল ২০২৫"

### Summary Cards (Horizontal Scroll)
```
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ 👥 Total │ │📅 Today's│ │ 💰 Month │ │ 📝 Exams │
│ Students │ │Attendance│ │ Revenue  │ │ Upcoming │
│   47     │ │  82%     │ │ ৳71,500  │ │    3     │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
```

### Quick Action Grid (2×2)
- ➕ Add Student
- 📋 Start Attendance
- 💳 Add Payment
- 📝 Create Exam

### Charts Section (fl_chart)
- Monthly Revenue Bar Chart (last 6 months)
- Attendance Trend Line Chart (last 30 days)
- Course-wise Student Distribution (Pie Chart)

### Recent Activity Feed
- Last 10 admin actions (payment added, student enrolled, result published)

---

## 📚 2. Course Management

### 2.1 Course List Screen
- Grid view (2 columns) — Course cards
- প্রতিটি card: Thumbnail, Name, ৳Fee/month, Student count, Active badge
- Search bar + Filter chip (All / Active / Inactive)
- FAB: ➕ Add Course

### 2.2 Add / Edit Course — Form Fields

| Field | Widget | Required |
|---|---|---|
| Course Name | TextFormField | ✅ |
| Thumbnail | ImagePicker → Supabase Storage upload | ✅ |
| Description | TextFormField (multiline, 5 lines) | ✅ |
| Monthly Fee (৳) | TextFormField (number keyboard) | ✅ |
| Active Status | Switch widget | ✅ |

**Save action:**
1. Image upload → Supabase Storage → get public URL
2. Insert/update `courses` table
3. Show success SnackBar

### 2.3 Course Detail Screen — Tabs
- **Info Tab:** Course details + Edit button
- **Subjects Tab:** Subject list (drag-to-reorder)
- **Students Tab:** Enrolled students list
- **Stats Tab:** Revenue chart, attendance %

### 2.4 Subject Management

**Add Subject Fields:**
| Field | Widget |
|---|---|
| Subject Name | TextFormField |
| Description | TextFormField (optional) |
| Display Order | NumberField |

**Subject List:** ReorderableListView — drag করে order change

### 2.5 Chapter Management

**Add Chapter Fields:**
| Field | Widget |
|---|---|
| Chapter Name | TextFormField |
| Description | TextFormField (optional) |
| Display Order | NumberField |

### Business Rules
- Course delete → cascade: subjects, chapters, notes সব delete
- Active course, enrolled students আছে → fee change করলে AlertDialog warning
- Inactive course → নতুন enrollment block

---

## 👥 3. Student Management

### 3.1 Student List
- ListView — প্রতিটি tile: Avatar, Name, ID, Course badge, Due indicator
- Search: name / phone / ID দিয়ে
- Filter chips: Course | Due | Active/Inactive
- Sort: Name | Due Amount | Enrolled Date

### 3.2 Add Student — Form

| Field | Widget | Note |
|---|---|---|
| Photo | ImagePicker | Optional |
| Full Name (Bengali) | TextFormField | |
| Full Name (English) | TextFormField | |
| Phone | TextFormField (phone keyboard) | Login-এ use হবে |
| Guardian Phone | TextFormField | SMS যাবে |
| Date of Birth | DatePicker | |
| Class | DropdownButton | SSC / HSC / Admission |
| Address | TextFormField (multiline) | |

**After Save:**
- `users` table-এ insert, role: 'student'
- Student ID auto-generate: `RCC-2025-001` (sequential)
- Supabase Auth-এ phone register
- Welcome SMS পাঠানো হবে (SSL Wireless API via Dio)
- FCM token পরে app login করলে save হবে

### 3.3 Student Profile (Admin View)

**Header:** Photo, Name, ID, Status badge  
**Info Section:** Phone, Guardian phone, DOB, Class, Address  
**Edit button:** সব field editable

**Bottom Tabs:**
| Tab | Content |
|---|---|
| 📚 Courses | Enrolled courses list + Enroll button |
| 💳 Payments | Month-wise payment history |
| 📅 Attendance | Calendar view + % |
| 📝 Results | Exam results list |
| 🔔 Notifications | Sent notifications |
| 💬 Complaints | Student complaints |

### 3.4 Enroll Student in Course
- Student profile → "Enroll in Course" button
- DropdownButton: available courses
- Date picker: enrollment start date
- Confirm → `enrollments` table insert
- Auto: community group-এ add
- Auto: welcome push notification + SMS

### 3.5 Student Deactivation
- Soft delete: `is_active = false`
- All enrollments suspend
- Historical data preserve হবে
- Reactivate করা যাবে

---

## 💳 4. Payment Management

### 4.1 Payment Dashboard

**Summary Row (4 cards):**
- এই মাস Collected: ৳71,500
- Total Due: ৳18,000
- Overdue Students: 12
- আজকের Payments: 5

**Filter:** Course dropdown + Month picker + Status chips

### 4.2 Add Payment — Form

| Field | Widget | Note |
|---|---|---|
| Student | Autocomplete search | Name / ID দিয়ে খোঁজো |
| Course | Auto-fill (from enrollment) | |
| Month | MonthPicker | যেটার জন্য দিচ্ছে |
| Amount (৳) | TextFormField | Default: course fee |
| Payment Method | SegmentedButton | Cash / bKash / Nagad / Bank |
| Payment Date | DatePicker | Default: today |
| Note | TextFormField (optional) | |

**After Save:**
- `payments` table insert
- Corresponding `payment_dues` row: `status = 'paid'`
- Voucher PDF auto-generate (pdf dart package)
- Push notification + SMS to student
- Show "View Voucher" button in SnackBar

### 4.3 Due Management

**Due List Screen:**
- ListView: Student name, Course, Month, ৳Amount, Days overdue
- Color coding: 🔴 >30 days, 🟡 15-30 days, 🟢 <15 days
- Per item actions:
  - ✅ Mark as Paid → Add Payment screen (pre-filled)
  - 📱 Send SMS Reminder
  - 📝 Add note / partial payment

**Bulk Reminder:**
- Filter by course → Select All → Send SMS to all

**Auto Due Generation:**
- Supabase Edge Function: প্রতি মাসের ১ তারিখে cron job
- সব active enrolled students-দের জন্য due create

### 4.4 Voucher PDF Generation 🖨️

**Voucher Layout (A5 size):**
```
╔══════════════════════════════════════╗
║    🌟 RADIANCE COACHING CENTER       ║
║    Tongi, Gazipur | 01XXXXXXXXX      ║
╠══════════════════════════════════════╣
║  PAYMENT VOUCHER                     ║
║  Voucher No: RCC-VCH-2025-0001      ║
║  Date: 08 April 2025                 ║
╠══════════════════════════════════════╣
║  Student: Rahim Uddin                ║
║  ID: RCC-2025-012                    ║
║  Course: HSC Biology Batch           ║
║  Month: April 2025                   ║
╠══════════════════════════════════════╣
║  Amount: ৳1,500/-                    ║
║  In Words: One Thousand Five Hundred ║
║  Method: bKash                       ║
╠══════════════════════════════════════╣
║  Admin Signature: ____________       ║
║  Thank You! 🙏                       ║
╚══════════════════════════════════════╝
```

**Actions:**
- Share via WhatsApp / Messenger (share_plus)
- Save to Downloads folder
- Print (printing package)

---

## 📅 5. Attendance Management

### 5.1 Start Attendance Screen
- Date picker (default: today)
- Course dropdown
- "Start Attendance" → Attendance Taking screen

### 5.2 Attendance Taking Screen (Main Feature)

**Layout:**
```
Date: ০৮ এপ্রিল ২০২৫ | HSC Biology Batch
Progress: ━━━━━━━━━━━━━░░░░  12/35

╔══════════════════════════════════════╗
║                                      ║
║   👤  Rahim Uddin                   ║
║       ID: RCC-2025-012              ║
║                                      ║
║  ┌─────────────┐  ┌─────────────┐  ║
║  │  ✅ PRESENT │  │  ❌ ABSENT  │  ║
║  │   (Green)   │  │   (Red)     │  ║
║  └─────────────┘  └─────────────┘  ║
║                                      ║
╚══════════════════════════════════════╝

[◀ Previous]                  [Next ▶]
```

**Features:**
- Buttons বড় → accidental tap avoid
- Swipe gesture: right = Present, left = Absent
- Progress LinearProgressIndicator (top)
- Top-right: Grid icon → Jump to specific student
- Undo last action button
- Auto-save প্রতিটি record (no "Submit" needed at end)
- "Finish" button → Summary screen (কতজন present/absent)

### 5.3 Attendance Summary

**Per Session:**
- Date, Course, Total, Present count, Absent count, %
- Student list: Present (green) / Absent (red)
- Export PDF attendance sheet

**Reports:**
- By Date → সব course-এর attendance
- By Student → একজনের সব history (calendar heatmap)
- By Course → Month-wise % (line chart)
- Warning list: <75% attendance students

### 5.4 Past Attendance Edit
- Admin যেকোনো past record edit করতে পারবে
- Edit log: who changed, when, old value → new value

---

## 📝 6. Exam Management

### 6.1 Exam List
- Tabs: Upcoming | Live | Ended
- প্রতিটি card: Title, Course, Date-Time, Duration, Status chip
- FAB: ➕ Create Exam

### 6.2 Create Exam — Multi-Step Form

**Step 1 — Details:**
| Field | Widget |
|---|---|
| Title | TextFormField |
| Course | DropdownButton |
| Subject | DropdownButton (filtered by course) |
| Date & Time | DateTimePicker |
| Duration (min) | Slider + NumberField |
| Pass Marks | NumberField |
| Negative Marking | Switch + NumberField (-0.25) |
| Shuffle Questions | Switch |
| Show Result Immediately | Switch |
| Instructions | TextFormField (multiline) |

**Step 2 — Add Questions:**
- ListTile per question: question preview + edit/delete icons
- "Add Question" bottom sheet:
  - Question text (with math keyboard option)
  - Image (optional, ImagePicker)
  - Option A, B, C, D
  - Correct answer radio group
  - Marks field
  - Explanation (optional)
- Bulk import: JSON file upload (predefined format)

**Step 3 — Publish:**
- Preview exam summary
- Publish Now / Schedule for later
- Notify students toggle

### 6.3 Live Exam Monitor
- Real-time counter: Started / Submitted / Not Started
- Per student status: 🟢 Submitted, 🟡 In Progress, ⚪ Not Started
- Force end exam button
- Supabase Realtime subscription

---

## 📊 7. Result Management

### 7.1 MCQ Result (Auto-calculated)
- After exam end → auto score calculate from `exam_submissions`
- Grade assign (A+/A/A-/B/C/D/F)
- Rank calculate (DENSE_RANK in PostgreSQL)
- Insert/update `results` table

### 7.2 Manual Result Entry (Written Exam)
- Exam select → Student list → Enter score per student
- Grade auto-assign

### 7.3 Result Overview
- Score distribution histogram (fl_chart)
- Pass/Fail pie chart
- Top 10 leaderboard
- Class average indicator

### 7.4 Result Card PDF 🖨️
- Student name, photo, ID
- Exam name, subject, date
- Score, Grade, Rank, Pass/Fail
- Question-wise breakdown (optional)
- Admin signature

### 7.5 Publish Results
- "Publish" toggle → students-রা result দেখতে পাবে
- Auto push notification to all exam participants

---

## 📖 8. Notes & Content Management

### Navigation:
Course → Subject → Chapter → Notes List → Add/Edit Note

### Add Note — Types:

| Type | Input | Storage |
|---|---|---|
| PDF | FilePicker → upload | Supabase Storage |
| Text/HTML | Rich text editor | `content` column |
| Video (YouTube) | YouTube URL | `file_url` column |
| Video (Upload) | FilePicker → upload | Supabase Storage |
| Image | ImagePicker → upload | Supabase Storage |
| External Link | URL input | `file_url` column |

**Fields:** Title, Description, Type, File/URL, Published toggle

### Content Library
- All content list with storage size
- Filter by course/subject/type
- Storage usage bar (Supabase 5GB free)
- Bulk delete

---

## 🔔 9. Notification Management

### 9.1 Send Notification Screen

**Target Selection:**
- All students (radio)
- By course (course dropdown)
- Individual student (search)

**Content:**
- Title field
- Body/Message field (multiline)
- Template picker (dropdown):
  - Payment Reminder
  - Exam Tomorrow
  - Result Published
  - Holiday Notice
  - Custom

**Channel:**
- In-app (insert to `notifications` table) ✅
- Push (FCM via Edge Function) ✅
- SMS (SSL Wireless API) ✅ (toggle per notification)

### 9.2 Auto Notifications (Edge Function Triggered)

| Event | Trigger | Message |
|---|---|---|
| Monthly due created | 1st of month | "এপ্রিল মাসের পেমেন্ট বাকি আছে" |
| Exam in 24hr | Cron check | "আগামীকাল Chemistry MCQ পরীক্ষা" |
| Result published | Admin action | "তোমার রেজাল্ট দেখা যাচ্ছে" |
| Note added | Admin action | "নতুন স্টাডি মেটেরিয়াল যোগ হয়েছে" |
| Attendance < 75% | Weekly check | "তোমার উপস্থিতি ৭৫%-এর নিচে" |

### 9.3 SMS Log
- Sent SMS history: To, Content, Time, Status (delivered/failed)
- SMS balance checker (API call)

---

## 🏠 10. Home Page CMS

**Admin থেকে control করা যাবে:**

| Element | Type | Action |
|---|---|---|
| Banner Slider | Image upload | Add/Remove/Reorder |
| Notice Board | Text + Date | Add/Edit/Delete |
| Featured Courses | Course select | Show/Hide |
| Marketing Block | Image + Text | Add/Edit/Delete |
| Announcement Popup | Text | Enable/Disable |

**Interface:** Drag-to-reorder list, each item: Edit / Toggle visibility / Delete

---

## 🧠 11. Question Bank Management

### Add Question (to Q-Bank):
| Field | Widget |
|---|---|
| Course → Subject → Chapter | Cascading dropdowns |
| Question Type | SegmentedButton (MCQ/Short/Broad) |
| Question Text | TextFormField (LaTeX support) |
| Options A-D | TextFormFields (MCQ only) |
| Correct Answer | RadioGroup (MCQ only) |
| Answer Text | TextFormField (Short/Broad) |
| Difficulty | SegmentedButton (Easy/Medium/Hard) |
| Source | DropdownButton (Board/Admission/Practice) |
| Year | NumberField (optional) |

### Bulk Import:
- JSON format upload
- CSV format support
- Preview before import

---

## 📈 12. Reports & Analytics

| Report | Filters | Export |
|---|---|---|
| Student List | Course, Status | PDF / CSV |
| Payment Report | Month, Course, Status | PDF / CSV |
| Due Report | Month, Course | PDF |
| Attendance Report | Date range, Course | PDF |
| Exam Performance | Exam, Course | PDF |
| Monthly Revenue | Date range | PDF |

All reports use the `pdf` dart package for generation.

---

## ⚙️ 13. Admin Settings

| Section | Options |
|---|---|
| Coaching Info | Name, address, phone, logo upload |
| Academic Session | Start/End date |
| Auto Due | ON/OFF + date of month |
| Grading Scale | Customize grade % ranges |
| Voucher Header | Logo + center name on PDF |
| Admin Profile | Name, photo, password change |
| SMS Config | API key, sender ID |
| FCM Config | Server key (if manual) |
| Data Backup | Export full data as JSON/CSV |

---

## 🎨 Admin UI Design Notes (Flutter)

### Colors:
```dart
// theme.dart
static const Color primary = Color(0xFF1A3C6E);    // Deep Blue
static const Color accent = Color(0xFFF5A623);     // Golden Yellow
static const Color success = Color(0xFF27AE60);
static const Color danger = Color(0xFFE74C3C);
static const Color background = Color(0xFFF8F9FA);
```

### Font:
```dart
// google_fonts package
GoogleFonts.hindSiliguri()   // Bengali text
GoogleFonts.nunito()          // English text / Numbers
```

### Navigation (Admin):
- Drawer navigation (side menu)
- Bottom nav: 🏠 Dashboard | 👥 Students | 💳 Payments | 📅 Attendance | ⚙️ More
