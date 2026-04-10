# 📖 CLASSNOTE UPLOAD SYSTEM — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)

---

# 🗄️ DATABASE SCHEMA

```sql
-- =============================================
-- NOTES (Chapter-level content)
-- =============================================
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  type VARCHAR(20) NOT NULL
    CHECK (type IN ('pdf','text','video_youtube','video_upload','image','link')),

  -- Content
  file_url TEXT,                   -- Supabase Storage URL (pdf/image/video)
  youtube_url TEXT,                -- YouTube link
  external_url TEXT,               -- Any external link
  text_content TEXT,               -- Rich text (MD + LaTeX)

  -- Meta
  file_size_kb INT,                -- For storage display
  duration_seconds INT,            -- For video
  thumbnail_url TEXT,              -- Custom thumbnail

  is_published BOOLEAN DEFAULT false,
  view_count INT DEFAULT 0,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- STUDENT NOTE PROGRESS
-- =============================================
CREATE TABLE note_progress (
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  is_viewed BOOLEAN DEFAULT false,
  viewed_at TIMESTAMPTZ,
  video_watched_seconds INT DEFAULT 0,  -- For video progress
  PRIMARY KEY(student_id, note_id)
);
```

---

# 👨‍💼 ADMIN SIDE

## A1. Content Management Home

```
📖 ক্লাসনোট ব্যবস্থাপনা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

কোর্স নির্বাচন: [HSC Biology Batch ▼]

┌──────────┐ ┌──────────┐ ┌──────────┐
│ 📄 PDF   │ │ 🎬 Video │ │ 📝 Text  │
│  ৪৫টি   │ │  ১২টি   │ │  ৩৩টি   │
└──────────┘ └──────────┘ └──────────┘

[➕ নতুন নোট যোগ করুন]  [📂 Bulk Upload]

━━━ কোর্স হায়ারার্কি ━━━━━━━━━━━━━━━━━━━━

▼ রসায়ন
   ▼ অধ্যায় ৩: মোলের ধারণা       [+Add Note]
      📄 মোলের ধারণা — লেকচার নোট    👁 ১৫৪  [✏️][🗑️]
      🎬 মোলের অংক (YouTube)          👁  ৮৭   [✏️][🗑️]
      📝 সূত্র সংকলন (Rich Text)       👁 ২০১  [✏️][🗑️]
   ▶ অধ্যায় ৪: বিক্রিয়া              [+Add Note]
▶ পদার্থবিজ্ঞান
```

## A2. Add Note Screen

```
নতুন নোট যোগ করুন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

শিরোনাম: [মোলের ধারণা — লেকচার নোট     ]
বিবরণ:   [মোল, মোলার ভর, অ্যাভোগাড্রো  ]

কন্টেন্টের ধরন:
[📄 PDF] [🎬 YT Video] [🎬 Upload Video]
[📝 Text] [🖼️ Image] [🔗 Link]
```

### Per Type — Upload Area:

**PDF:**
```
[📂 PDF ফাইল নির্বাচন করুন]
Selected: chapter3_notes.pdf (2.4 MB)
Progress: ████████████ 100% ✅
URL: storage.supabase.co/.../chapter3_notes.pdf

[🖼️ Thumbnail (optional)]
```

**YouTube Video:**
```
YouTube URL:
[https://youtube.com/watch?v=xxxxxxx      ]
→ Auto-fetch: Title + Thumbnail preview দেখাবে

"মোলের ধারণা | Chemistry | HSC"
[Thumbnail preview]
Duration: 23:45
```

**Upload Video:**
```
[📂 Video ফাইল নির্বাচন করুন] (MP4, max 500MB)
Progress: ████████░░░░ 67% uploading...
```

**Rich Text (MD + LaTeX):**
```
┌──────────────────────────────────────────────┐
│ ## মোলের ধারণা                               │
│                                              │
│ **মোল** হলো পদার্থের পরিমাণের একক।         │
│                                              │
│ $$1 \text{ mol} = 6.022 \times 10^{23}$$    │
│                                              │
│ ### সূত্রসমূহ                                │
│ $$n = \frac{m}{M}$$                          │
│                                              │
│                          [👁️ Live Preview]   │
└──────────────────────────────────────────────┘
```

**Image:**
```
[📷 ছবি নির্বাচন করুন]
Preview দেখাবে
```

**External Link:**
```
URL: [https://example.com/resource         ]
Link Title: [সহায়ক রিসোর্স                 ]
```

### Common Fields:
```
Published: [✅ এখনই প্রকাশ করুন]
            [  Draft হিসেবে রাখুন]

[✅ নোট সংরক্ষণ করুন]
```

Save হলে → enrolled students-এর push notification (if published)

## A3. Bulk PDF Upload

```
📂 Bulk Upload
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

কোর্স:    [HSC Biology Batch ▼]
বিষয়:     [রসায়ন ▼]
অধ্যায়:   [অধ্যায় ৩ ▼]

[📂 একাধিক PDF নির্বাচন করুন]

নির্বাচিত ফাইল:
chapter3_part1.pdf   2.1 MB  ████████████ ✅
chapter3_part2.pdf   1.8 MB  ████████████ ✅
chapter3_formulas.pdf 0.5 MB ████████████ ✅

সব Published: [✅]

[✅ সব Upload করুন]
```

## A4. Edit Note

- Title, description, published toggle editable
- File replace করা যাবে (নতুন upload → পুরনো Storage-এ delete)
- Content type change করা যাবে না (delete করে নতুন add)

## A5. Storage Usage

```
⚙️ Storage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
মোট ব্যবহৃত: 1.2 GB / 5 GB

PDF:   ████░░░░  680 MB
Video: ██░░░░░░  380 MB
Image: █░░░░░░░  140 MB

[🗑️ পুরনো ফাইল মুছুন]
```

---

# 🎓 STUDENT SIDE

## S1. Course Content Browser

```
HSC Biology Batch
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▼ রসায়ন
   ▼ অধ্যায় ৩: মোলের ধারণা
      📄 লেকচার নোট          ✅ পড়া হয়েছে
      🎬 মোলের অংক (23:45)   ▶ ৬০% দেখা হয়েছে
      📝 সূত্র সংকলন          🆕 নতুন
      🔗 সহায়ক রিসোর্স

   ▶ অধ্যায় ৪: বিক্রিয়া       🆕 ২টি নতুন

▶ পদার্থবিজ্ঞান
```

Icon legend:
- ✅ পড়া/দেখা হয়েছে
- 🆕 নতুন (last 7 days)
- ▶ ৬০% partially watched
- ⬜ দেখা হয়নি

## S2. Note Viewers

**PDF Viewer:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
← লেকচার নোট            [📥 Download]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[PDF renders here — flutter_pdfview]
Page 3 / 12  ← Page counter

[−] [+] Zoom          [⤢ Full Screen]
```

**YouTube Player:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
← মোলের অংক (YouTube)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[YouTube Player — youtube_player_flutter]
0.75x  1x  1.25x  1.5x  2x   [⤢]

23:45 total  |  ৬০% দেখা হয়েছে
```

**Rich Text Viewer:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
← সূত্র সংকলন              [Aa Font]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

মোলের ধারণা
━━━━━━━━━━━━

মোল হলো পদার্থের পরিমাণের একক।

1 mol = 6.022 × 10²³

সূত্রসমূহ:
      m
n = ─────
      M
```

**Image Viewer:**
- InteractiveViewer (pinch zoom, pan)
- Download button

**External Link:**
- url_launcher → browser

## S3. Downloaded Notes (Offline)

```
📥 ডাউনলোড করা নোট
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ব্যবহৃত: 45 MB

📄 লেকচার নোট — CH3    2.1 MB  [🗑️]
📄 সূত্র সংকলন — CH4   0.8 MB  [🗑️]
🖼️ বিক্রিয়ার ছবি        1.2 MB  [🗑️]

[🗑️ সব মুছুন]
```

## S4. Notifications

- নতুন note publish হলে: *"রসায়ন — অধ্যায় ৩-এ নতুন স্টাডি মেটেরিয়াল যোগ হয়েছে 📄"*

---

# 🔧 FLUTTER IMPLEMENTATION

```dart
class NoteService {
  // Upload PDF to Supabase Storage
  Future<String> uploadFile(File file, String path) async {
    await supabase.storage.from('notes').upload(path, file);
    return supabase.storage.from('notes').getPublicUrl(path);
  }

  // Fetch YouTube metadata
  Future<YoutubeInfo> fetchYoutubeInfo(String url) async {
    final videoId = YoutubePlayer.convertUrlToId(url)!;
    final thumbUrl = YoutubePlayer.getThumbnail(videoId: videoId);
    // Use oembed API for title + duration
    final res = await Dio().get('https://www.youtube.com/oembed?url=$url&format=json');
    return YoutubeInfo(title: res.data['title'], thumbnailUrl: thumbUrl);
  }

  // Mark note as viewed
  Future<void> markViewed(String studentId, String noteId) async {
    await supabase.from('note_progress').upsert({
      'student_id': studentId,
      'note_id': noteId,
      'is_viewed': true,
      'viewed_at': DateTime.now().toIso8601String(),
    }, onConflict: 'student_id,note_id');
    // Increment view count
    await supabase.rpc('increment_view_count', params: {'note_id': noteId});
  }

  // Download PDF for offline
  Future<File> downloadPdf(String url, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/notes/$filename');
    if (await file.exists()) return file;
    await Dio().download(url, file.path);
    return file;
  }
}
```

---

# ✅ FEATURE CHECKLIST

## Admin:
- [ ] Hierarchy browser (Course→Subject→Chapter→Notes)
- [ ] Add PDF note (file picker + Supabase Storage upload)
- [ ] Add YouTube video (URL + auto thumbnail fetch)
- [ ] Add upload video (file picker)
- [ ] Add rich text (MD + LaTeX + live preview)
- [ ] Add image
- [ ] Add external link
- [ ] Bulk PDF upload (multiple files)
- [ ] Publish / Draft toggle
- [ ] Edit note (title, description, replace file)
- [ ] Delete note (+ Storage cleanup)
- [ ] View count display
- [ ] Storage usage dashboard
- [ ] Push notification on publish

## Student:
- [ ] Hierarchy browser with viewed/new indicators
- [ ] PDF viewer (in-app, zoomable, page counter)
- [ ] PDF download for offline
- [ ] YouTube player (speed control, fullscreen)
- [ ] Video progress tracking (resume from last position)
- [ ] Rich text viewer (MD + LaTeX rendered)
- [ ] Image viewer (pinch zoom)
- [ ] External link (browser)
- [ ] Downloaded notes manager
- [ ] New note push notification
