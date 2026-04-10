# 🧠 QUESTION BANK SYSTEM — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)

---

## 📌 Overview

| Feature | Details |
|---|---|
| Question Types | MCQ, CQ (Creative Question) |
| Content Support | Markdown + LaTeX (KaTeX) + Optional Image |
| Hierarchy | Session → Subject → Chapter → Questions |
| Sessions | SSC, HSC (expandable) |
| Admin | Add / Edit / Delete / Bulk JSON Upload |
| Student | Browse / Search / Practice / Bookmark |

---

# 🗄️ DATABASE SCHEMA

```sql
-- =============================================
-- SESSION (SSC / HSC)
-- =============================================
CREATE TABLE qbank_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,           -- 'SSC', 'HSC'
  name_bn TEXT NOT NULL,        -- 'এসএসসি', 'এইচএসসি'
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO qbank_sessions (name, name_bn, display_order) VALUES
  ('SSC', 'এসএসসি', 1),
  ('HSC', 'এইচএসসি', 2);

-- =============================================
-- SUBJECT (per session)
-- =============================================
CREATE TABLE qbank_subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES qbank_sessions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,           -- 'Chemistry', 'Physics', 'Math'
  name_bn TEXT NOT NULL,        -- 'রসায়ন', 'পদার্থবিজ্ঞান', 'গণিত'
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(session_id, name)
);

-- =============================================
-- CHAPTER (per subject)
-- =============================================
CREATE TABLE qbank_chapters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject_id UUID NOT NULL REFERENCES qbank_subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- MCQ QUESTIONS
-- =============================================
CREATE TABLE qbank_mcq (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chapter_id UUID NOT NULL REFERENCES qbank_chapters(id) ON DELETE CASCADE,

  -- Content (Markdown + LaTeX supported)
  question_text TEXT NOT NULL,    -- MD/LaTeX: "মোলার ঘনত্বের একক কোনটি? $C = \\frac{n}{V}$"
  image_url TEXT,                 -- Optional image (Supabase Storage)

  -- Options (Markdown + LaTeX)
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,

  -- Answer
  correct_option CHAR(1) NOT NULL CHECK (correct_option IN ('A','B','C','D')),
  explanation TEXT,               -- MD/LaTeX explanation (shown after answer)
  explanation_image_url TEXT,

  -- Metadata
  difficulty VARCHAR(10) DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source VARCHAR(50),             -- 'board_2023', 'admission_dhaka_2022', 'practice', 'custom'
  board_year INT,                 -- 2023, 2022, ...
  board_name TEXT,                -- 'Dhaka', 'Chittagong', 'All'
  tags TEXT[],                    -- ['mole', 'concentration', 'stoichiometry']

  is_published BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- CQ QUESTIONS (Creative Question)
-- =============================================
CREATE TABLE qbank_cq (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chapter_id UUID NOT NULL REFERENCES qbank_chapters(id) ON DELETE CASCADE,

  -- Stem / উদ্দীপক (the scenario/passage)
  stem_text TEXT NOT NULL,        -- MD/LaTeX supported
  stem_image_url TEXT,            -- Optional image for stem

  -- Sub-questions
  -- গ (3rd sub-question — Application, 3 marks)
  ga_text TEXT NOT NULL,          -- "উদ্দীপকের বিক্রিয়াটি সমতা করো।"
  ga_image_url TEXT,
  ga_answer TEXT,                 -- Model answer (MD/LaTeX)
  ga_marks INT DEFAULT 3,

  -- ঘ (4th sub-question — Higher ability, 4 marks)
  gha_text TEXT NOT NULL,
  gha_image_url TEXT,
  gha_answer TEXT,                -- Model answer
  gha_marks INT DEFAULT 4,

  -- Metadata
  difficulty VARCHAR(10) DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source VARCHAR(50),
  board_year INT,
  board_name TEXT,
  tags TEXT[],

  is_published BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- BOOKMARKS
-- =============================================
CREATE TABLE qbank_bookmarks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_type VARCHAR(5) NOT NULL CHECK (question_type IN ('mcq', 'cq')),
  question_id UUID NOT NULL,      -- References either qbank_mcq.id or qbank_cq.id
  note TEXT,                      -- Student personal note on this question
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, question_type, question_id)
);

-- =============================================
-- PRACTICE SESSION (optional tracking)
-- =============================================
CREATE TABLE qbank_practice_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id),
  chapter_id UUID REFERENCES qbank_chapters(id),
  question_type VARCHAR(5) CHECK (question_type IN ('mcq', 'cq', 'mixed')),
  total_questions INT,
  correct_answers INT,
  started_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE qbank_practice_answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES qbank_practice_sessions(id) ON DELETE CASCADE,
  question_id UUID NOT NULL,
  question_type VARCHAR(5),
  selected_option CHAR(1),        -- MCQ only
  is_correct BOOLEAN              -- MCQ only
);
```

---

# 📐 CONTENT FORMAT (Markdown + LaTeX)

সব `_text` field এই format support করে:

## Markdown Support:
```markdown
**Bold text**
*Italic*
`code`
> blockquote
- list item
```

## LaTeX Support (KaTeX):
```
Inline:  $E = mc^2$
Block:   $$\frac{n}{V} = C$$

Chemistry: $\text{H}_2\text{SO}_4 + 2\text{NaOH} \rightarrow \text{Na}_2\text{SO}_4 + 2\text{H}_2\text{O}$
```

## Example MCQ question_text:
```
নিচের বিক্রিয়াটি দেখো:

$$\text{N}_2 + 3\text{H}_2 \rightarrow 2\text{NH}_3$$

এই বিক্রিয়ায় **১ মোল** $\text{N}_2$ থেকে কত মোল $\text{NH}_3$ উৎপন্ন হয়?
```

## Example CQ stem:
```
রহিম $0.1 \text{ mol/L}$ NaOH দ্রবণ তৈরি করতে চায়।
সে **৫০০ mL** দ্রবণ তৈরি করতে চাইলে,

$$m = n \times M$$

যেখানে $M_{\text{NaOH}} = 40 \text{ g/mol}$
```

## Flutter rendering:
- `flutter_markdown` — Markdown rendering
- `flutter_math_fork` — LaTeX/KaTeX rendering
- Custom parser: `$...$` → Math widget, বাকি → Markdown widget

---

# 👨‍💼 ADMIN SIDE

---

## A1. Question Bank Home Screen

```
🧠 প্রশ্নব্যাংক
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────┐ ┌──────────┐ ┌──────────┐
│ 📝 মোট   │ │ ✅ MCQ   │ │ 📖 CQ    │
│ প্রশ্ন   │ │          │ │          │
│  ১,২৪৫  │ │   ৮৯৭   │ │   ৩৪৮   │
└──────────┘ └──────────┘ └──────────┘

━━━ Session নির্বাচন ━━━━━━━━━━━━━━━━━━━

┌──────────────────────────┐   ┌──────────────────────────┐
│       📗 SSC             │   │       📘 HSC             │
│   এসএসসি                │   │   এইচএসসি               │
│   ৫৪৩ প্রশ্ন             │   │   ৭০২ প্রশ্ন             │
└──────────────────────────┘   └──────────────────────────┘

[➕ প্রশ্ন যোগ করুন]  [📤 JSON আপলোড]  [🔍 খুঁজুন]
```

---

## A2. Hierarchy Browser (Session → Subject → Chapter)

```
📗 SSC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▼ রসায়ন (Chemistry)                   [+Add Chapter]
   ├── অধ্যায় ১: পরমাণুর গঠন       87 প্রশ্ন  [>]
   ├── অধ্যায় ২: পর্যায় সারণি      64 প্রশ্ন  [>]
   ├── অধ্যায় ৩: মোলের ধারণা       112 প্রশ্ন [>]
   └── অধ্যায় ৪: রাসায়নিক বিক্রিয়া  78 প্রশ্ন  [>]

▶ পদার্থবিজ্ঞান (Physics)             [+Add Chapter]
▶ গণিত (Math)                         [+Add Chapter]

[+Add Subject]
```

---

## A3. Chapter Question List

```
অধ্যায় ৩: মোলের ধারণা — ১১২টি প্রশ্ন
SSC → রসায়ন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ফিল্টার: [সব ▼] [MCQ ▼] [CQ ▼] [সহজ/মধ্যম/কঠিন ▼]
🔍 [প্রশ্ন খুঁজুন...]

[➕ MCQ যোগ করুন]  [➕ CQ যোগ করুন]  [📤 JSON আপলোড]

━━━ MCQ (৮৬টি) ━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────┐
│ MCQ  🟡 মধ্যম  |  Board 2022               │
│ মোলার ঘনত্বের একক কোনটি?                   │
│ (A) g/L  (B) mol/L ✓  (C) g/mol  (D) mol/g │
│ [✏️ সম্পাদনা]  [🗑️ মুছুন]  [👁️ Preview]   │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│ MCQ  🔴 কঠিন  |  Practice                  │
│ $0.5\text{ mol}$ NaCl কে $250\text{ mL}$... │
│ (A) 2 mol/L ✓  (B) 1 mol/L  ...            │
│ [✏️ সম্পাদনা]  [🗑️ মুছুন]  [👁️ Preview]   │
└─────────────────────────────────────────────┘

━━━ CQ (২৬টি) ━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────┐
│ CQ  🟡 মধ্যম  |  Dhaka Board 2023          │
│ উদ্দীপক: রহিম ল্যাবে $\text{H}_2\text{SO}_4$... │
│ গ. বিক্রিয়ার সমীকরণ লিখো।                 │
│ ঘ. মোলের ধারণা ব্যাখ্যা করো।               │
│ [✏️ সম্পাদনা]  [🗑️ মুছুন]  [👁️ Preview]   │
└─────────────────────────────────────────────┘
```

---

## A4. Add MCQ Screen

```
নতুন MCQ প্রশ্ন
Session: SSC → রসায়ন → অধ্যায় ৩
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

প্রশ্নের টেক্সট: (Markdown + LaTeX সমর্থিত)
┌──────────────────────────────────────────────┐
│ মোলার ঘনত্বের একক কোনটি?                    │
│ $$C = \frac{n}{V}$$                          │
│                                              │
│                              [👁️ Preview]    │
└──────────────────────────────────────────────┘
[📷 ছবি যোগ করুন (optional)]  → image_url

অপশনসমূহ:
(A) ┌──────────────────────────────────────┐
    │ g/L                                  │
    └──────────────────────────────────────┘
(B) ┌──────────────────────────────────────┐
    │ mol/L                                │
    └──────────────────────────────────────┘
(C) ┌──────────────────────────────────────┐
    │ g/mol                                │
    └──────────────────────────────────────┘
(D) ┌──────────────────────────────────────┐
    │ mol/g                                │
    └──────────────────────────────────────┘

সঠিক উত্তর:
( ) A   (●) B   ( ) C   ( ) D

ব্যাখ্যা (optional — answer দেখার পর দেখাবে):
┌──────────────────────────────────────────────┐
│ মোলার ঘনত্বের একক $\text{mol/L}$ কারণ...    │
│                                              │
│                              [👁️ Preview]    │
└──────────────────────────────────────────────┘
[📷 ব্যাখ্যার ছবি (optional)]

কঠিনতা:  ( ) সহজ  (●) মধ্যম  ( ) কঠিন

উৎস:
[Board Exam ▼]  সাল: [2022]  বোর্ড: [Dhaka ▼]
বা: [Practice / Custom]

ট্যাগ: [mole] [concentration] [+যোগ করুন]

[✅ প্রশ্ন সংরক্ষণ করুন]
```

---

## A5. Add CQ Screen

```
নতুন CQ প্রশ্ন
Session: HSC → রসায়ন → অধ্যায় ৫
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

উদ্দীপক (Stem): (Markdown + LaTeX সমর্থিত)
┌──────────────────────────────────────────────┐
│ রহিম ল্যাবে $0.1 \text{ mol/L}$ $H_2SO_4$   │
│ দ্রবণ তৈরি করে। সে জানে,                    │
│ $$M_{H_2SO_4} = 98 \text{ g/mol}$$          │
│ দ্রবণটির আয়তন $500 \text{ mL}$।             │
│                                              │
│                              [👁️ Preview]    │
└──────────────────────────────────────────────┘
[📷 উদ্দীপকের ছবি (optional)]

━━━ গ নম্বর প্রশ্ন (৩ নম্বর) ━━━━━━━━━━━━━━

প্রশ্ন:
┌──────────────────────────────────────────────┐
│ উদ্দীপকে উল্লিখিত দ্রবণ তৈরিতে কত গ্রাম    │
│ $H_2SO_4$ প্রয়োজন?                          │
└──────────────────────────────────────────────┘
[📷 গ-এর ছবি (optional)]

মডেল উত্তর (optional):
┌──────────────────────────────────────────────┐
│ **সমাধান:**                                  │
│ $n = C \times V = 0.1 \times 0.5 = 0.05$mol │
│ $m = n \times M = 0.05 \times 98 = 4.9$g    │
│ সুতরাং, **৪.৯ গ্রাম** $H_2SO_4$ প্রয়োজন।  │
└──────────────────────────────────────────────┘

━━━ ঘ নম্বর প্রশ্ন (৪ নম্বর) ━━━━━━━━━━━━━━

প্রশ্ন:
┌──────────────────────────────────────────────┐
│ উদ্দীপকের দ্রবণটি $\text{NaOH}$ দ্রবণের    │
│ সাথে বিক্রিয়া করলে কী ঘটবে? বিশ্লেষণ করো।  │
└──────────────────────────────────────────────┘
[📷 ঘ-এর ছবি (optional)]

মডেল উত্তর:
┌──────────────────────────────────────────────┐
│ $$H_2SO_4 + 2NaOH \rightarrow ...$$         │
└──────────────────────────────────────────────┘

কঠিনতা:  ( ) সহজ  (●) মধ্যম  ( ) কঠিন
উৎস: [Board Exam ▼]  সাল: [2023]  বোর্ড: [Dhaka ▼]
ট্যাগ: [acid-base] [titration]

[✅ প্রশ্ন সংরক্ষণ করুন]
```

---

## A6. Live Preview Widget

Add/Edit screen-এ `[👁️ Preview]` button tap করলে:

```
┌─────────────────────────────────────────────────────┐
│ PREVIEW                                             │
│ ─────────────────────────────────────────────────  │
│                                                     │
│ মোলার ঘনত্বের একক কোনটি?                           │
│                                                     │
│         n                                           │
│   C = ─────                                         │
│         V                                           │
│                                                     │
│  ○  (A)  g/L                                        │
│  ●  (B)  mol/L                                      │
│  ○  (C)  g/mol                                      │
│  ○  (D)  mol/g                                      │
│                                                     │
│ ─────────────────────────────────────────────────  │
│ ✅ সঠিক উত্তর: (B) mol/L                           │
│                                                     │
│ ব্যাখ্যা: মোলার ঘনত্বের একক mol/L কারণ...         │
└─────────────────────────────────────────────────────┘
```

Real-time preview — type করার সাথে সাথে update হবে।

---

## A7. 📤 JSON Bulk Upload System

### কীভাবে কাজ করবে:
```
Admin JSON file তৈরি করে
    ↓
App-এ "JSON আপলোড" button press
    ↓
FilePicker দিয়ে JSON file select
    ↓
App JSON parse করে (database-এ save হয় না এখনো)
    ↓
Preview screen — সব প্রশ্ন দেখায়
    ↓
Admin validate করে → "সব Import করুন" press
    ↓
Batch insert to database
```

### MCQ JSON Format:

```json
{
  "session": "HSC",
  "subject": "রসায়ন",
  "chapter": "অধ্যায় ৩: মোলের ধারণা",
  "type": "mcq",
  "questions": [
    {
      "question_text": "মোলার ঘনত্বের একক কোনটি? $$C = \\frac{n}{V}$$",
      "image_url": null,
      "option_a": "g/L",
      "option_b": "mol/L",
      "option_c": "g/mol",
      "option_d": "mol/g",
      "correct_option": "B",
      "explanation": "মোলার ঘনত্ব = মোল/আয়তন, তাই একক **mol/L**",
      "explanation_image_url": null,
      "difficulty": "medium",
      "source": "board",
      "board_year": 2022,
      "board_name": "Dhaka",
      "tags": ["mole", "concentration"]
    },
    {
      "question_text": "$0.5$ mol NaCl কে $250$ mL দ্রবণে দ্রবীভূত করলে মোলারিটি কত?",
      "image_url": null,
      "option_a": "2 mol/L",
      "option_b": "1 mol/L",
      "option_c": "0.5 mol/L",
      "option_d": "0.125 mol/L",
      "correct_option": "A",
      "explanation": "$$C = \\frac{n}{V} = \\frac{0.5}{0.250} = 2 \\text{ mol/L}$$",
      "difficulty": "hard",
      "source": "practice",
      "board_year": null,
      "board_name": null,
      "tags": ["molarity", "calculation"]
    }
  ]
}
```

### CQ JSON Format:

```json
{
  "session": "HSC",
  "subject": "রসায়ন",
  "chapter": "অধ্যায় ৫: রাসায়নিক বন্ধন",
  "type": "cq",
  "questions": [
    {
      "stem_text": "রহিম ল্যাবে $0.1$ mol/L $H_2SO_4$ দ্রবণ তৈরি করে।\n$$M_{H_2SO_4} = 98 \\text{ g/mol}$$",
      "stem_image_url": null,
      "ga_text": "উদ্দীপকে উল্লিখিত দ্রবণ তৈরিতে কত গ্রাম $H_2SO_4$ প্রয়োজন?",
      "ga_image_url": null,
      "ga_answer": "**সমাধান:**\n$$n = C \\times V = 0.1 \\times 0.5 = 0.05 \\text{ mol}$$\n$$m = 0.05 \\times 98 = 4.9 \\text{ g}$$",
      "ga_marks": 3,
      "gha_text": "উদ্দীপকের দ্রবণটি NaOH দ্রবণের সাথে বিক্রিয়া করলে কী ঘটবে? বিশ্লেষণ করো।",
      "gha_image_url": null,
      "gha_answer": "$$H_2SO_4 + 2NaOH \\rightarrow Na_2SO_4 + 2H_2O$$\nএটি একটি প্রশম বিক্রিয়া...",
      "gha_marks": 4,
      "difficulty": "medium",
      "source": "board",
      "board_year": 2023,
      "board_name": "Dhaka",
      "tags": ["acid-base", "neutralization"]
    }
  ]
}
```

### JSON Upload UI:

```
📤 JSON আপলোড
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[📂 JSON ফাইল নির্বাচন করুন]

ফাইল নির্বাচিত: chemistry_mcq_ch3.json

━━━ পার্স ফলাফল ━━━━━━━━━━━━━━━━━━━━━━━

✅ সেশন: HSC
✅ বিষয়: রসায়ন
✅ অধ্যায়: অধ্যায় ৩
✅ প্রশ্নের ধরন: MCQ
✅ মোট প্রশ্ন: ২৫টি

━━━ প্রশ্নের Preview ━━━━━━━━━━━━━━━━━━━

#1  [MCQ 🟡]  মোলার ঘনত্বের একক কোনটি?...  ✅ Valid
#2  [MCQ 🔴]  $0.5$ mol NaCl কে $250$ mL... ✅ Valid
#3  [MCQ 🟡]  নিচের কোনটি মোলার ভর নয়?...  ⚠️ সঠিক উত্তর নেই
#4  [MCQ 🟢]  অ্যাভোগাড্রো সংখ্যার মান...   ✅ Valid
...

━━━ ত্রুটি (Error) ━━━━━━━━━━━━━━━━━━━━━━

⚠️ #3: correct_option field খালি আছে
⚠️ #18: option_c field নেই

[⚠️ ২টি ত্রুটি বাদ দিয়ে ২৩টি import করুন]
[✅ সব ঠিক থাকলে Import করুন]
[✕ বাতিল]
```

### Dart JSON Parser:

```dart
class QBankJsonImporter {
  
  /// JSON file parse করে → validate → return ImportResult
  Future<ImportResult> parseJsonFile(File file) async {
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    final sessionName = json['session'] as String;
    final subjectName = json['subject'] as String;
    final chapterName = json['chapter'] as String;
    final type = json['type'] as String;         // 'mcq' | 'cq'
    final questions = json['questions'] as List;

    final valid = <Map>[];
    final errors = <ImportError>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i] as Map<String, dynamic>;
      final result = type == 'mcq'
          ? _validateMCQ(q, i + 1)
          : _validateCQ(q, i + 1);

      if (result.isValid) valid.add(q);
      else errors.addAll(result.errors);
    }

    return ImportResult(
      session: sessionName,
      subject: subjectName,
      chapter: chapterName,
      type: type,
      validQuestions: valid,
      errors: errors,
      totalCount: questions.length,
    );
  }

  ValidationResult _validateMCQ(Map q, int index) {
    final errors = <ImportError>[];
    if ((q['question_text'] as String?)?.isEmpty ?? true)
      errors.add(ImportError(index, 'question_text খালি'));
    if ((q['option_a'] as String?)?.isEmpty ?? true)
      errors.add(ImportError(index, 'option_a খালি'));
    if (!['A','B','C','D'].contains(q['correct_option']))
      errors.add(ImportError(index, 'correct_option A/B/C/D হতে হবে'));
    return ValidationResult(errors.isEmpty, errors);
  }

  /// Database-এ batch insert (only after user confirms)
  Future<void> importToDatabase({
    required ImportResult result,
    required String chapterId,
    required String adminId,
  }) async {
    if (result.type == 'mcq') {
      final rows = result.validQuestions.map((q) => {
        'chapter_id': chapterId,
        'question_text': q['question_text'],
        'image_url': q['image_url'],
        'option_a': q['option_a'],
        'option_b': q['option_b'],
        'option_c': q['option_c'],
        'option_d': q['option_d'],
        'correct_option': q['correct_option'],
        'explanation': q['explanation'],
        'difficulty': q['difficulty'] ?? 'medium',
        'source': q['source'],
        'board_year': q['board_year'],
        'board_name': q['board_name'],
        'tags': q['tags'] ?? [],
        'created_by': adminId,
      }).toList();

      // Batch insert (Supabase handles up to 1000 rows per call)
      await supabase.from('qbank_mcq').insert(rows);
    } else {
      // Same pattern for CQ
    }
  }
}
```

---

# 🎓 STUDENT SIDE

---

## S1. Question Bank Home (Student)

```
🧠 প্রশ্নব্যাংক
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 [যেকোনো প্রশ্ন খুঁজুন...]

[📗 SSC]           [📘 HSC]

[⭐ আমার Bookmark (২৩টি)]

[🎯 Practice Mode শুরু করুন]
```

---

## S2. Browse (Session → Subject → Chapter)

```
📘 HSC → রসায়ন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▼ অধ্যায় ৩: মোলের ধারণা
   MCQ: ৮৬টি  |  CQ: ২৬টি
   [➡️ দেখুন]

▶ অধ্যায় ৪: রাসায়নিক বিক্রিয়া
   MCQ: ৭৪টি  |  CQ: ১৮টি

▶ অধ্যায় ৫: রাসায়নিক বন্ধন
   MCQ: ৯২টি  |  CQ: ৩১টি
```

---

## S3. Chapter Question List (Student)

```
অধ্যায় ৩: মোলের ধারণা
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ফিল্টার: [MCQ] [CQ]  কঠিনতা: [সব ▼]
উৎস: [সব ▼]  সাল: [সব ▼]

┌────────────────────────────────────────────┐
│ MCQ  🟡  Board 2022 · Dhaka               │
│                                            │
│ মোলার ঘনত্বের একক কোনটি?                  │
│ $$C = \frac{n}{V}$$                        │
│                                            │
│  (A) g/L                                   │
│  (B) mol/L                                 │
│  (C) g/mol                                 │
│  (D) mol/g                                 │
│                                            │
│ [উত্তর দেখাও]           [⭐ Bookmark]      │
└────────────────────────────────────────────┘
```

**"উত্তর দেখাও" press করলে:**
```
┌────────────────────────────────────────────┐
│ ✅ সঠিক উত্তর: (B) mol/L                  │
│                                            │
│ ব্যাখ্যা:                                  │
│ মোলার ঘনত্বের একক mol/L কারণ              │
│ $$C = \frac{n}{V}$$                        │
│ যেখানে n = মোল, V = লিটারে আয়তন           │
└────────────────────────────────────────────┘
```

---

## S4. CQ View (Student)

```
┌────────────────────────────────────────────────┐
│ CQ  🟡  Dhaka Board 2023                       │
│                                                │
│ উদ্দীপক:                                       │
│ রহিম ল্যাবে $0.1$ mol/L $H_2SO_4$ দ্রবণ তৈরি  │
│ করে। $M_{H_2SO_4} = 98$ g/mol এবং আয়তন       │
│ $500$ mL।                                      │
│                                                │
│ [📷 উদ্দীপকের ছবি] (যদি থাকে)                 │
│                                                │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                │
│ গ.  উদ্দীপকে উল্লিখিত দ্রবণ তৈরিতে কত গ্রাম  │
│     $H_2SO_4$ প্রয়োজন?          (৩ নম্বর)    │
│                                                │
│           [গ-এর উত্তর দেখাও ▼]                │
│                                                │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                │
│ ঘ.  উদ্দীপকের দ্রবণটি NaOH-এর সাথে           │
│     বিক্রিয়া করলে কী ঘটবে? বিশ্লেষণ করো।    │
│                                       (৪ নম্বর)│
│           [ঘ-এর উত্তর দেখাও ▼]                │
│                                                │
│ [⭐ Bookmark করুন]                             │
└────────────────────────────────────────────────┘
```

গ/ঘ answer আলাদা আলাদা toggle — student চাইলে একটা দেখে বাকিটা নিজে চেষ্টা করতে পারবে।

---

## S5. 🎯 Practice Mode (MCQ)

```
Practice শুরু করুন
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Session: [HSC ▼]
বিষয়:   [রসায়ন ▼]
অধ্যায়: [অধ্যায় ৩ ▼] (বা সব অধ্যায়)
ধরন:    [MCQ]
কঠিনতা: [মধ্যম ▼]  বা  [মিশ্র]
প্রশ্ন সংখ্যা: [১০] ▼ (10 / 20 / 30 / সব)

[🎯 Practice শুরু করুন]
```

**Practice Screen (MCQ one by one):**
```
প্রশ্ন ৫/১০
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$0.5$ mol NaCl কে $250$ mL দ্রবণে
দ্রবীভূত করলে মোলারিটি কত?

  ○  (A)  2 mol/L
  ○  (B)  1 mol/L
  ○  (C)  0.5 mol/L
  ○  (D)  0.125 mol/L

[উত্তর দাও]  [⭐ Bookmark]  [⏭️ Skip]
```

**After answer:**
```
✅ সঠিক!   বা   ❌ ভুল! সঠিক: (A)

ব্যাখ্যা:
$$C = \frac{n}{V} = \frac{0.5}{0.250} = 2 \text{ mol/L}$$

[পরের প্রশ্ন ▶]
```

**Practice Summary:**
```
🎉 Practice শেষ!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
মোট: ১০  |  সঠিক: ৭  |  ভুল: ৩
স্কোর: ৭০%

ভুল প্রশ্নগুলো:
• #3 মোলার ভর সংক্রান্ত...   [আবার দেখুন]
• #7 অ্যাভোগাড্রো সংখ্যা...  [আবার দেখুন]

[🔄 আবার Practice] [📖 অধ্যায়ে ফিরুন] [⭐ ভুলগুলো Bookmark]
```

---

## S6. Bookmark System

### Bookmark করার উপায়:
- যেকোনো MCQ বা CQ screen-এ `[⭐ Bookmark]` button
- Optional note লেখা যাবে: "এটা ভালো করে পড়তে হবে"

### Bookmark List Screen:
```
⭐ আমার Bookmarks (২৩টি)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ফিল্টার: [MCQ ▼] [CQ ▼] [রসায়ন ▼] [সব অধ্যায় ▼]

┌─────────────────────────────────────────┐
│ MCQ  রসায়ন · অধ্যায় ৩                 │
│ মোলার ঘনত্বের একক কোনটি?...            │
│ 📝 নোট: "সূত্র মনে রাখতে হবে"           │
│ [দেখুন]  [🗑️ সরিয়ে নিন]               │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ CQ  রসায়ন · অধ্যায় ৫                  │
│ উদ্দীপক: রহিম ল্যাবে $H_2SO_4$...       │
│ 📝 নোট: "ঘ-এর উত্তর বুঝিনি"             │
│ [দেখুন]  [🗑️ সরিয়ে নিন]               │
└─────────────────────────────────────────┘

[🎯 Bookmark থেকে Practice করুন]
```

---

## S7. Search (Global)

```
🔍 প্রশ্ন খুঁজুন

[মোলার ঘনত্ব               ] ✕

ফিল্টার: [HSC ▼] [রসায়ন ▼] [MCQ ▼]

━━━ ফলাফল (১৮টি) ━━━━━━━━━━━━━━━━━━━━━

MCQ · অধ্যায় ৩
মোলার ঘনত্বের একক কোনটি?  [দেখুন]

CQ · অধ্যায় ৩
...দ্রবণের মোলার ঘনত্ব নির্ণয় করো  [দেখুন]

MCQ · অধ্যায় ৪
মোলার ঘনত্বের সাথে মোলালিটির পার্থক্য...  [দেখুন]
```

Full-text search: Supabase `ilike` বা `ts_vector` (PostgreSQL full-text search)

---

# 🔧 FLUTTER IMPLEMENTATION NOTES

## Mixed Content Renderer (MD + LaTeX):

```dart
/// Renders a string that may contain both Markdown and LaTeX
/// LaTeX: $inline$ or $$block$$
class MixedContentRenderer extends StatelessWidget {
  final String content;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    // Split content by LaTeX delimiters
    final parts = _parseParts(content);

    return Wrap(
      children: parts.map((part) {
        if (part.isLatex && part.isBlock) {
          return Math.tex(
            part.text,
            mathStyle: MathStyle.display,
          );
        } else if (part.isLatex) {
          return Math.tex(part.text, mathStyle: MathStyle.text);
        } else {
          return MarkdownBody(data: part.text);
        }
      }).toList(),
    );
  }

  List<ContentPart> _parseParts(String text) {
    // Regex: $$...$$ for block, $...$ for inline
    // Returns ordered list of text/latex parts
  }
}

// Usage:
MixedContentRenderer(content: question.questionText)
```

## Question Card Widget:

```dart
class McqQuestionCard extends StatefulWidget {
  final QbankMcq question;
  final bool showAnswer;          // Toggle answer visibility
  final bool isBookmarked;
  final void Function(bool) onBookmarkChanged;
}

class CqQuestionCard extends StatefulWidget {
  final QbankCq question;
  final bool showGaAnswer;        // গ-এর উত্তর দেখাও
  final bool showGhaAnswer;       // ঘ-এর উত্তর দেখাও
  final bool isBookmarked;
  final void Function(bool) onBookmarkChanged;
}
```

## Repository:

```dart
class QBankRepository {
  // Hierarchy
  Future<List<QbankSession>> getSessions();
  Future<List<QbankSubject>> getSubjects(String sessionId);
  Future<List<QbankChapter>> getChapters(String subjectId);

  // Questions
  Future<List<QbankMcq>> getMcqQuestions({
    required String chapterId,
    String? difficulty,
    String? source,
    int? boardYear,
    int? limit,
    int? offset,
  });

  Future<List<QbankCq>> getCqQuestions({
    required String chapterId,
    String? difficulty,
    int? limit,
    int? offset,
  });

  // Search
  Future<List<dynamic>> searchQuestions(String query, {
    String? sessionId,
    String? subjectId,
    String? type,
  });

  // Bookmarks
  Future<void> toggleBookmark({
    required String studentId,
    required String questionType,
    required String questionId,
    String? note,
  });

  Future<List<BookmarkItem>> getBookmarks(String studentId);

  // Practice
  Future<List<QbankMcq>> getPracticeQuestions({
    required String chapterId,
    String? difficulty,
    required int count,
  });

  // Admin CRUD
  Future<QbankMcq> addMcq(QbankMcq mcq);
  Future<QbankCq> addCq(QbankCq cq);
  Future<void> updateMcq(QbankMcq mcq);
  Future<void> updateCq(QbankCq cq);
  Future<void> deleteMcq(String id);
  Future<void> deleteCq(String id);

  // JSON Import
  Future<void> batchInsertMcq(List<QbankMcq> questions);
  Future<void> batchInsertCq(List<QbankCq> questions);
}
```

---

# 📊 KEY SQL QUERIES

```sql
-- Chapter-wise question count (for list display)
SELECT
  c.id, c.name_bn,
  COUNT(m.id) AS mcq_count,
  COUNT(q.id) AS cq_count
FROM qbank_chapters c
LEFT JOIN qbank_mcq m ON m.chapter_id = c.id AND m.is_published = true
LEFT JOIN qbank_cq  q ON q.chapter_id = c.id AND q.is_published = true
WHERE c.subject_id = 'SUBJECT_UUID'
GROUP BY c.id, c.name_bn, c.display_order
ORDER BY c.display_order;

-- Full-text search (MCQ)
SELECT * FROM qbank_mcq
WHERE chapter_id IN (
  SELECT id FROM qbank_chapters WHERE subject_id IN (
    SELECT id FROM qbank_subjects WHERE session_id = 'SESSION_UUID'
  )
)
AND (
  question_text ILIKE '%মোলার%' OR
  option_a ILIKE '%মোলার%' OR
  option_b ILIKE '%মোলার%'
)
AND is_published = true
LIMIT 20;

-- Student-এর bookmarks (MCQ + CQ combined)
SELECT
  'mcq' as type, b.question_id, b.note, b.created_at,
  m.question_text, ch.name_bn as chapter,
  s.name_bn as subject
FROM qbank_bookmarks b
JOIN qbank_mcq m ON m.id = b.question_id
JOIN qbank_chapters ch ON m.chapter_id = ch.id
JOIN qbank_subjects s ON ch.subject_id = s.id
WHERE b.student_id = 'STUDENT_UUID' AND b.question_type = 'mcq'

UNION ALL

SELECT
  'cq' as type, b.question_id, b.note, b.created_at,
  q.stem_text as question_text, ch.name_bn as chapter,
  s.name_bn as subject
FROM qbank_bookmarks b
JOIN qbank_cq q ON q.id = b.question_id
JOIN qbank_chapters ch ON q.chapter_id = ch.id
JOIN qbank_subjects s ON ch.subject_id = s.id
WHERE b.student_id = 'STUDENT_UUID' AND b.question_type = 'cq'

ORDER BY created_at DESC;

-- Practice questions (random selection)
SELECT * FROM qbank_mcq
WHERE chapter_id = 'CHAPTER_UUID'
  AND difficulty = 'medium'
  AND is_published = true
ORDER BY RANDOM()
LIMIT 10;
```

---

# ✅ FEATURE CHECKLIST

## Admin:
- [ ] Session / Subject / Chapter CRUD
- [ ] Add MCQ (MD + LaTeX + image + options + answer + explanation)
- [ ] Add CQ (stem + গ + ঘ + model answers + images)
- [ ] Live Preview while typing
- [ ] Edit MCQ / CQ
- [ ] Delete MCQ / CQ
- [ ] Chapter question list (filter by type/difficulty/source)
- [ ] JSON file upload (FilePicker)
- [ ] JSON parse + validate (no DB save yet)
- [ ] Import preview screen (valid + errors)
- [ ] Batch insert to DB after confirmation
- [ ] Image upload (Supabase Storage → image_url)
- [ ] Publish / Unpublish toggle

## Student:
- [ ] Session → Subject → Chapter browser
- [ ] MCQ view with reveal answer toggle
- [ ] CQ view with গ/ঘ answer separate toggles
- [ ] Bookmark MCQ / CQ (with personal note)
- [ ] Bookmark list (filter by subject/chapter)
- [ ] Practice Mode (MCQ — random/selected)
- [ ] Practice summary + score
- [ ] Wrong answers bookmark from practice
- [ ] Global search (across all questions)
- [ ] Filter by difficulty / source / year
- [ ] Mixed MD + LaTeX rendering
- [ ] Image display (CachedNetworkImage)
