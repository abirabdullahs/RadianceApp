# 💳 PAYMENT MANAGEMENT SYSTEM — Full Documentation
## Radiance Coaching Center App (Flutter + Supabase)
### Physical Batch — Complete Payment Control

---

## 📌 Fee Types (Physical Batch)

| Fee Type | বাংলা নাম | কখন নেওয়া হয় | Recurring? |
|---|---|---|---|
| Admission Fee | ভর্তি ফি | একবার, ভর্তির সময় | ❌ |
| Monthly Fee | মাসিক বেতন | প্রতি মাসে | ✅ |
| Material Fee | শিক্ষা উপকরণ ফি | বই/নোট দেওয়ার সময় | ❌ |
| Exam Fee | পরীক্ষা ফি | নির্দিষ্ট পরীক্ষার আগে | ❌ |
| Special Fee | বিশেষ ফি | ইভেন্ট, ট্যুর ইত্যাদি | ❌ |
| Fine | জরিমানা | লেট পেমেন্ট, ইউনিফর্ম ইত্যাদি | ❌ |

**সব কিছু Admin থেকে control হবে। Student শুধু দেখবে।**

---

# 🗄️ DATABASE SCHEMA

```sql
-- =============================================
-- PAYMENT TYPES (Admin configures)
-- =============================================
CREATE TABLE payment_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  code VARCHAR(30) UNIQUE NOT NULL,     -- 'admission','monthly','material','exam','special','fine'
  is_recurring BOOLEAN DEFAULT false,
  default_amount NUMERIC(10,2),
  is_active BOOLEAN DEFAULT true,
  color_hex VARCHAR(7) DEFAULT '#1A3C6E',
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO payment_types (name, name_bn, code, is_recurring, default_amount, color_hex) VALUES
  ('Admission Fee',  'ভর্তি ফি',        'admission', false, 500.00,  '#9B59B6'),
  ('Monthly Fee',    'মাসিক বেতন',      'monthly',   true,  1500.00, '#1A3C6E'),
  ('Material Fee',   'উপকরণ ফি',        'material',  false, 300.00,  '#27AE60'),
  ('Exam Fee',       'পরীক্ষা ফি',      'exam',      false, 100.00,  '#E67E22'),
  ('Special Fee',    'বিশেষ ফি',        'special',   false, 0.00,    '#3498DB'),
  ('Fine',           'জরিমানা',         'fine',      false, 0.00,    '#E74C3C');

-- =============================================
-- PAYMENT LEDGER (Every single transaction)
-- =============================================
CREATE TABLE payment_ledger (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  voucher_no VARCHAR(40) UNIQUE,           -- RCC-2025-0001 (auto)
  student_id UUID NOT NULL REFERENCES users(id),
  course_id UUID NOT NULL REFERENCES courses(id),
  payment_type_id UUID NOT NULL REFERENCES payment_types(id),
  payment_type_code VARCHAR(30),           -- Denormalized
  for_month DATE,                          -- NULL for non-recurring
  amount_due NUMERIC(10,2) NOT NULL,
  amount_paid NUMERIC(10,2) NOT NULL,
  discount_amount NUMERIC(10,2) DEFAULT 0,
  fine_amount NUMERIC(10,2) DEFAULT 0,
  -- net = due - discount + fine
  -- balance = paid - net  (positive=advance, negative=partial/due)
  payment_method VARCHAR(20) NOT NULL
    CHECK (payment_method IN ('cash','bkash','nagad','rocket','bank','other')),
  transaction_ref VARCHAR(100),            -- bKash/Nagad TrxID
  status VARCHAR(20) NOT NULL DEFAULT 'paid'
    CHECK (status IN ('paid','partial','advance','waived')),
  note TEXT,                               -- Admin internal note
  description TEXT,                        -- Shown on voucher to student
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES users(id)
);

-- Auto voucher number trigger
CREATE OR REPLACE FUNCTION set_voucher_no()
RETURNS TRIGGER AS $$
DECLARE
  yr TEXT := TO_CHAR(now(), 'YYYY');
  seq INT;
BEGIN
  SELECT COUNT(*) + 1 INTO seq
  FROM payment_ledger WHERE voucher_no LIKE 'RCC-' || yr || '-%';
  NEW.voucher_no := 'RCC-' || yr || '-' || LPAD(seq::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_voucher_no
  BEFORE INSERT ON payment_ledger
  FOR EACH ROW EXECUTE FUNCTION set_voucher_no();

-- =============================================
-- PAYMENT SCHEDULE (What SHOULD be paid)
-- =============================================
CREATE TABLE payment_schedule (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id),
  course_id UUID NOT NULL REFERENCES courses(id),
  payment_type_id UUID NOT NULL REFERENCES payment_types(id),
  payment_type_code VARCHAR(30),
  for_month DATE,                          -- For monthly fees
  due_date DATE NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending'
    CHECK (status IN ('pending','paid','partial','overdue','waived')),
  paid_amount NUMERIC(10,2) DEFAULT 0,
  remaining_amount NUMERIC(10,2),
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, course_id, payment_type_id, for_month)
);

-- =============================================
-- DISCOUNT RULES
-- =============================================
CREATE TABLE discount_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_bn TEXT NOT NULL,
  discount_type VARCHAR(20) DEFAULT 'percentage'
    CHECK (discount_type IN ('percentage','fixed')),
  discount_value NUMERIC(8,2) NOT NULL,
  applies_to VARCHAR(30) DEFAULT 'monthly',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- STUDENT DISCOUNT ASSIGNMENTS
-- =============================================
CREATE TABLE student_discounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id),
  course_id UUID NOT NULL REFERENCES courses(id),
  discount_rule_id UUID REFERENCES discount_rules(id),
  custom_amount NUMERIC(10,2),
  custom_reason TEXT,
  applies_to VARCHAR(30) DEFAULT 'monthly',
  valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
  valid_until DATE,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- ADVANCE BALANCE (Credit/Overpaid)
-- =============================================
CREATE TABLE advance_balance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES users(id),
  course_id UUID NOT NULL REFERENCES courses(id),
  balance NUMERIC(10,2) DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, course_id)
);
```

---

# 👨‍💼 ADMIN SIDE — Full Payment Control

---

## A1. Payment Dashboard

### Summary Cards Row (Scrollable):
```
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ 💰 এই মাস    │ │ 🔴 মোট বকেয়া  │ │ 👥 বকেয়া     │ │ ✅ আজ        │ │ 💚 এডভান্স   │
│ কালেকশন      │ │              │ │ শিক্ষার্থী   │ │ পেমেন্ট      │ │ ব্যালেন্স    │
│ ৳ ৭১,৫০০    │ │ ৳ ১৮,৫০০   │ │ ১২ জন        │ │ ৫ জন         │ │ ৳ ৩,০০০    │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

### Fee Type Breakdown:
```
এপ্রিল ২০২৫ কালেকশন breakdown
🔵 মাসিক বেতন:   ৳ ৬০,০০০  (৪০/৪৭ জন)
🟣 ভর্তি ফি:      ৳  ৫,০০০  (১০ জন নতুন)
🟢 উপকরণ ফি:     ৳  ৪,৫০০  (১৫ জন)
🟠 পরীক্ষা ফি:    ৳  ২,০০০  (২০ জন)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
মোট: ৳ ৭১,৫০০
```

### Revenue Charts (fl_chart):
- Monthly Bar Chart: last 12 months
- Fee Type Pie Chart: breakdown percentage
- Collection Trend Line Chart

### Recent Transactions (Last 10):
```
আজ ২:৩০ PM  |  রহিম উদ্দিন  |  মাসিক বেতন এপ্রিল  |  ৳ ১,৫০০  |  Cash  ✅
আজ ১:১৫ PM  |  সাদিয়া ইসলাম |  ভর্তি ফি            |  ৳ ৫০০    |  bKash ✅
```

**Quick Actions:**
`[➕ পেমেন্ট নাও]  [📋 বকেয়া লিস্ট]  [📊 রিপোর্ট]  [⚙️ সেটিংস]`

---

## A2. Add Payment Screen (সবচেয়ে গুরুত্বপূর্ণ screen)

### Step 1 — Student Select:
```
🔍 শিক্ষার্থী খুঁজুন (নাম / আইডি / ফোন)
```
- Autocomplete: real-time suggestions
- প্রতিটি suggestion: Photo + Name + ID + Course + Due (red badge)
- Select করলে info card:
```
┌────────────────────────────────────────┐
│ 👤 রহিম উদ্দিন  |  RCC-2025-012       │
│ HSC Biology Batch 2025                 │
│ 🔴 বকেয়া: ৳ ১,৫০০ (এপ্রিল মাসিক)     │
│ 💚 এডভান্স: ৳ ০                       │
└────────────────────────────────────────┘
```

### Step 2 — Fee Type (Multi-select):
```
ফি ধরন নির্বাচন করুন:
[🔵 মাসিক বেতন] [🟣 ভর্তি ফি] [🟢 উপকরণ ফি]
[🟠 পরীক্ষা ফি] [🔷 বিশেষ ফি] [🔴 জরিমানা]
```
একসাথে multiple select করা যাবে (ভর্তির দিন admission + monthly + material একসাথে)

### Step 3 — Amount & Details:

**Monthly Fee:**
```
মাস নির্বাচন: [এপ্রিল ২০২৫ ▼]

নির্ধারিত পরিমাণ:  ৳ ১,৫০০
ছাড়:           -  ৳ ০
জরিমানা:        +  ৳ ০
━━━━━━━━━━━━━━━━━━━━━━
নেট পরিমাণ:       ৳ ১,৫০০

পরিশোধিত পরিমাণ: [১,৫০০] ← editable (partial payment support)
```

**Multiple Overdue Months:**
```
বকেয়া মাসগুলো:
☑ ফেব্রুয়ারি  ৳ ১,৫০০  (৬০ দিন বকেয়া)
☑ মার্চ        ৳ ১,৫০০  (৩০ দিন বকেয়া)
☑ এপ্রিল       ৳ ১,৫০০  (এই মাস)
━━━━━━━━━━━━━━━━━━━━━━
মোট: ৳ ৪,৫০০
[সব মাস একসাথে নাও]  [আলাদা আলাদা নাও]
```

**Material / Exam / Special / Fine:**
```
বিবরণ: [Chemistry Notes — Chapter 1-5]
পরিমাণ: [৩০০] ← editable
```

### Common Fields (সব type):
```
পেমেন্ট পদ্ধতি: [💵 নগদ] [📱 bKash] [📱 Nagad] [📱 Rocket] [🏦 ব্যাংক]

ট্রানজেকশন রেফ: [          ] (bKash/Nagad-এ mandatory)
তারিখ:          [০৮/০৪/২০২৫] (default today, editable)
নোট (admin):    [            ] (শুধু admin দেখবে)
ভাউচার নোট:    [            ] (voucher-এ print হবে)
```

### Discount Apply (Optional):
```
[🏷️ ছাড় প্রয়োগ করুন ▼]
  ছাড়ের ধরন: [মেধাবৃত্তি ▼]  বা  [কাস্টম]
  পরিমাণ: ৳ [___] বা [___]%
  কারণ: [              ]
```

### Submit:
```
┌──────────────────────────────────────┐
│  মোট গৃহীত: ৳ ১,৫০০                 │
│  [✅ পেমেন্ট সংরক্ষণ করুন]            │
└──────────────────────────────────────┘
```

**After Submit → Success Dialog:**
```
✅ পেমেন্ট সফল!
ভাউচার নং: RCC-2025-0047
৳ ১,৫০০ — মাসিক বেতন (এপ্রিল ২০২৫)
রহিম উদ্দিন

[📄 ভাউচার দেখুন]  [📤 শেয়ার]  [🔄 নতুন পেমেন্ট]
```

---

## A3. Due Management (বকেয়া ব্যবস্থাপনা)

### Filter Bar:
```
[সব কোর্স ▼] [সব ধরন ▼] [সব মাস ▼] [🔴 ওভারডিউ only]
```

### Due List — প্রতিটি row:
```
┌─────────────────────────────────────────────────────┐
│ 👤 রহিম উদ্দিন (RCC-2025-012)                       │
│ HSC Biology  |  মাসিক বেতন  |  এপ্রিল ২০২৫         │
│ ৳ ১,৫০০  |  🔴 ৩০ দিন বকেয়া                       │
│                                                     │
│ [💳 পেমেন্ট নাও]  [📱 SMS]  [📝 নোট]               │
└─────────────────────────────────────────────────────┘
```

**Overdue color:**
- 🟡 1-15 দিন | 🟠 16-30 দিন | 🔴 30+ দিন

**Bulk Actions:**
```
☑ সব নির্বাচন (১২ জন)
[📱 সবাইকে SMS পাঠাও]  [📊 PDF রিপোর্ট]
```

### Manual Due Generate:
```
[⚙️ এই মাসের Due Generate করুন]
  Course: [HSC Biology Batch ▼]
  মাস: [এপ্রিল ২০২৫]
  পরিমাণ: [১,৫০০]
  Due Date: [১৫/০৪/২০২৫]
  [✅ Generate করুন]
```

---

## A4. Admission Enrollment — Fee Setup

ভর্তির সময় সব fee একসাথে নেওয়া:

```
নতুন শিক্ষার্থী ভর্তি — Fee Collection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

শিক্ষার্থী: রহিম উদ্দিন (নতুন)
কোর্স: HSC Biology Batch 2025

┌──────────────────────────────────────┐
│ ভর্তি ফি:          ৳ 500  ☑         │
│ প্রথম মাসের বেতন:  ৳ 1,500 ☑         │
│ উপকরণ ফি:          ৳ 300  ☑         │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│ মোট:               ৳ 2,300          │
│ ছাড়:             - ৳ 0              │
│ পরিশোধযোগ্য:        ৳ 2,300          │
└──────────────────────────────────────┘

পেমেন্ট পদ্ধতি: [💵 নগদ]
[✅ ভর্তি সম্পন্ন করুন]
```

প্রতিটি fee-র জন্য আলাদা voucher → অথবা একটি consolidated voucher।

---

## A5. Student Payment History (Admin View)

Student profile → Payment tab:

```
রহিম উদ্দিন — পেমেন্ট ইতিহাস
ফিল্টার: [সব ধরন ▼] [২০২৫ ▼]

━━━ Summary Bar ━━━━━━━━━━━━━━━━━━━━
মোট পরিশোধিত: ৳ ৯,৮০০  |  বকেয়া: ৳ ১,৫০০  |  এডভান্স: ৳ ০

━━━ এপ্রিল ২০২৫ ━━━━━━━━━━━━━━━━━━━━

🔴 মাসিক বেতন     ৳ ১,৫০০   বকেয়া
   Due: ১৫/০৪/২০২৫  (৩০ দিন বকেয়া)
   [💳 পেমেন্ট নাও]

━━━ মার্চ ২০২৫ ━━━━━━━━━━━━━━━━━━━━━

✅ মাসিক বেতন     ৳ ১,৫০০   পরিশোধিত
   ০৫/০৩/২০২৫  •  Cash  •  RCC-2025-0031
   [📄 ভাউচার দেখুন]  [🖨️ Reprint]

━━━ ফেব্রুয়ারি ২০২৫ ━━━━━━━━━━━━━━━━━━

🟡 মাসিক বেতন     ৳ ১,৫০০   আংশিক পরিশোধিত
   পরিশোধিত: ৳ ১,০০০  |  বাকি: ৳ ৫০০
   ২০/০২/২০২৫  •  bKash  •  RCC-2025-0018
   [📄 ভাউচার]  [💳 বাকিটা নাও]

━━━ জানুয়ারি ২০২৫ ━━━━━━━━━━━━━━━━━━━

✅ ভর্তি ফি        ৳ ৫০০    পরিশোধিত
   ০১/০১/২০২৫  •  Cash  •  RCC-2025-0001  [📄]

✅ মাসিক বেতন     ৳ ১,৫০০   পরিশোধিত
   ০১/০১/২০২৫  •  Cash  •  RCC-2025-0002  [📄]

✅ উপকরণ ফি       ৳ ৩০০    পরিশোধিত
   Chemistry Notes — Jan batch
   ০৩/০১/২০২৫  •  Cash  •  RCC-2025-0005  [📄]
```

---

## A6. Discount Management

### Discount Rules (Settings → Discounts):
```
[➕ নতুন নিয়ম যোগ করুন]

ভাই-বোন ছাড় (Sibling Discount)
১০% — মাসিক বেতনে  [✏️ Edit]  [🗑️ Delete]

মেধাবৃত্তি (Merit Scholarship)
৳ ৩০০ — মাসিক বেতনে  [✏️ Edit]  [🗑️ Delete]
```

### Student-এ Assign (Student Profile → "ছাড় যোগ করুন"):
```
নিয়ম: [মেধাবৃত্তি ▼]  বা  [কাস্টম: ৳___]
কারণ: [দারিদ্র্য সহায়তা]
কোন ফি: [মাসিক বেতন ▼]
শুরু: [০১/০৪/২০২৫]  শেষ: [ ] (খালি = স্থায়ী)
```

পরবর্তী payment-এ auto apply হবে।

---

## A7. Reports

### Monthly Collection Report:
```
Filter: Month + Course

মাসিক বেতন:   ৳ ৬০,০০০  (৪০/৪৭ জন)
ভর্তি ফি:      ৳  ৫,০০০  (১০ জন)
উপকরণ ফি:     ৳  ৪,৫০০  (১৫ জন)
পরীক্ষা ফি:    ৳  ২,০০০  (২০ জন)
━━━━━━━━━━━━━━━━━━━━━━━━━━━
মোট: ৳ ৭১,৫০০  |  বকেয়া: ৳ ১০,৫০০

[📄 PDF]  [📊 CSV]
```

### Due Report:
```
নং | নাম           | কোর্স       | ধরন   | পরিমাণ  | দিন
1  | রহিম উদ্দিন   | HSC Biology | মাসিক | ৳ ১,৫০০ | ৩০
2  | সাদিয়া ইসলাম  | HSC Chem   | মাসিক | ৳ ১,৫০০ | ১৫

মোট বকেয়া: ৳ ১৮,০০০
[📄 PDF]  [📱 সবাইকে SMS]
```

### Student Annual Report:
```
রহিম উদ্দিন — ২০২৫

মাস      | বেতন    | উপকরণ | পরীক্ষা | মোট    | স্ট্যাটাস
জানুয়ারি | ৳ ১,৫০০ | ৳ ৩০০ | —      | ৳ ১,৮০০| ✅
ফেব্রুয়ারি| ৳ ১,৫০০ | —     | ৳ ১০০  | ৳ ১,৬০০| 🟡 আংশিক
মার্চ    | ৳ ১,৫০০ | —     | —      | ৳ ১,৫০০| ✅
এপ্রিল   | ৳ ১,৫০০ | —     | —      | ৳ ১,৫০০| 🔴 বকেয়া
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
পরিশোধিত: ৳ ৬,৪০০  |  বকেয়া: ৳ ২,০০০
ভর্তি ফি: ৳ ৫০০ ✅
```

---

## A8. Payment Settings (⚙️)

```
ডিফল্ট পরিমাণ:
মাসিক বেতন: ৳ [১,৫০০]
ভর্তি ফি:   ৳ [৫০০  ]
উপকরণ ফি:  ৳ [৩০০  ]
পরীক্ষা ফি: ৳ [১০০  ]

Auto Due Generation:
প্রতি মাসের [১] তারিখে
Due Date: ভর্তির তারিখ + [১৫] দিন

গ্রহণযোগ্য পেমেন্ট পদ্ধতি:
[✅] নগদ  [✅] bKash 01711-XXXXXX
[✅] Nagad 01711-XXXXXX  [ ] ব্যাংক

Voucher:
সেন্টারের নাম: [Radiance Coaching Center]
ঠিকানা:       [টঙ্গী, গাজীপুর         ]
ফোন:          [01711-XXXXXX          ]
লোগো:         [📷 আপলোড              ]
QR Code:      [✅] চালু রাখুন
```

---

## A9. SMS Templates

```
পেমেন্ট নিশ্চিতকরণ (auto):
"প্রিয় {name}, {month} মাসের {type} ৳{amount}
পরিশোধিত হয়েছে। ভাউচার: {voucher_no}
ধন্যবাদ — Radiance"

বকেয়া রিমাইন্ডার:
"প্রিয় {name}, {month} মাসের বেতন ৳{amount}
এখনও বকেয়া আছে। দ্রুত পরিশোধ করুন।
— Radiance Coaching Center"

[একজনকে] / [কোর্সের সবাইকে] / [সব বকেয়াদের]
```

---

# 🧾 VOUCHER SYSTEM

## Voucher Layout (A5 Print-ready):

```
╔══════════════════════════════════════════════════╗
║         🌟 RADIANCE COACHING CENTER              ║
║         টঙ্গী, গাজীপুর | ০১৭XX-XXXXXX           ║
╠══════════════════════════════════════════════════╣
║   PAYMENT VOUCHER / পেমেন্ট রসিদ                ║
║   ভাউচার নং: RCC-2025-0047                      ║
║   তারিখ: ০৮ এপ্রিল ২০২৫                        ║
╠══════════════════════════════════════════════════╣
║   শিক্ষার্থী: রহিম উদ্দিন                        ║
║   আইডি: RCC-2025-012                            ║
║   কোর্স: HSC Biology Batch 2025                 ║
╠══════════════════════════════════════════════════╣
║   ফি ধরন: মাসিক বেতন (এপ্রিল ২০২৫)            ║
║   বিবরণ: —                                       ║
║   নির্ধারিত পরিমাণ:   ৳ ১,৫০০/-                  ║
║   ছাড়:              - ৳ ০/-                     ║
║   জরিমানা:           + ৳ ০/-                     ║
║   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     ║
║   মোট গৃহীত:          ৳ ১,৫০০/-                  ║
║   কথায়: এক হাজার পাঁচশত টাকা মাত্র              ║
║   পেমেন্ট পদ্ধতি: নগদ (Cash)                    ║
╠══════════════════════════════════════════════════╣
║  [QR: RCC-2025-0047]   Signature: ___________   ║
║                        রেডিয়েন্স কোচিং সেন্টার   ║
║         ধন্যবাদ! আপনার সন্তানের ভবিষ্যৎ         ║
║              আমাদের দায়িত্ব। 🙏                   ║
╚══════════════════════════════════════════════════╝
```

**Partial Payment Voucher — extra line:**
```
⚠️ আংশিক পেমেন্ট
পরিশোধিত: ৳ ১,০০০  |  বাকি: ৳ ৫০০
```

## Voucher Actions:
- **Print** (printing package — Bluetooth thermal printer support)
- **Share as PDF** (share_plus — WhatsApp, Messenger)
- **Share as Image** (PDF → PNG → share)
- **Download** (save to phone Downloads)
- **Reprint** (Payment history → tap any paid record)

---

# 🎓 STUDENT SIDE — Payment View

Student app-এ শুধু **দেখা যাবে**। কোনো add/edit নেই।

---

## S1. Payment Widget (Dashboard-এ):

```
┌──────────────────────────────────────┐
│ 💳 পেমেন্ট স্ট্যাটাস                  │
│                                      │
│ ✅ মার্চ — পরিশোধিত                   │
│ 🔴 এপ্রিল — ৳ ১,৫০০ বকেয়া           │
│                                      │
│ [বিস্তারিত দেখুন →]                   │
└──────────────────────────────────────┘
```

---

## S2. Payment Screen (Full):

### Summary Cards:
```
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ ✅ পরিশোধিত  │ │ 🔴 বকেয়া     │ │ 💚 এডভান্স   │
│ ৳ ৯,৮০০     │ │ ৳ ১,৫০০     │ │ ৳ ০          │
└──────────────┘ └──────────────┘ └──────────────┘
```

### Current Due Card (if any):
```
┌──────────────────────────────────────────────┐
│ ⚠️ বকেয়া পেমেন্ট                             │
│                                              │
│ মাসিক বেতন — এপ্রিল ২০২৫                   │
│ পরিমাণ: ৳ ১,৫০০                             │
│ Due: ১৫ এপ্রিল ২০২৫  (৭ দিন বাকি)           │
│                                              │
│ পেমেন্ট করুন:                                │
│ 📱 bKash: 01711-XXXXXX                      │
│ 📱 Nagad: 01711-XXXXXX                      │
│ 💵 সরাসরি কোচিং সেন্টারে আসুন               │
│                                              │
│ (পেমেন্ট করলে স্যার রসিদ দেবেন)              │
└──────────────────────────────────────────────┘
```

### Full Payment History:
```
ফিল্টার: [সব ধরন ▼] [২০২৫ ▼]

━━━ এপ্রিল ২০২৫ ━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 মাসিক বেতন          ৳ ১,৫০০   বকেয়া
   Due: ১৫ এপ্রিল ২০২৫

━━━ মার্চ ২০২৫ ━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ মাসিক বেতন          ৳ ১,৫০০   পরিশোধিত
   ০৫ মার্চ ২০২৫  •  নগদ  •  RCC-2025-0031
   [📄 ভাউচার দেখুন]

━━━ ফেব্রুয়ারি ২০২৫ ━━━━━━━━━━━━━━━━━━━━━━━

🟡 মাসিক বেতন          ৳ ১,৫০০   আংশিক
   পরিশোধিত: ৳ ১,০০০  |  বাকি: ৳ ৫০০
   ২০ ফেব্রুয়ারি ২০২৫  •  bKash  •  RCC-2025-0018
   [📄 ভাউচার দেখুন]

━━━ জানুয়ারি ২০২৫ ━━━━━━━━━━━━━━━━━━━━━━━━

✅ ভর্তি ফি             ৳ ৫০০    পরিশোধিত
   ০১ জানুয়ারি ২০২৫  •  নগদ  [📄]

✅ মাসিক বেতন           ৳ ১,৫০০  পরিশোধিত
   ০১ জানুয়ারি ২০২৫  •  নগদ  [📄]

✅ উপকরণ ফি             ৳ ৩০০    পরিশোধিত
   Chemistry Notes — Jan batch
   ০৩ জানুয়ারি ২০২৫  •  নগদ  [📄]
```

---

## S3. Voucher View (Student):

`[📄 ভাউচার দেখুন]` tap করলে:
- In-app PDF viewer (flutter_pdfview)
- Same layout admin-এর মতো

**Student actions:**
```
[📥 ডাউনলোড করুন]  [📤 শেয়ার করুন (WhatsApp)]
```

---

## S4. Notifications (Payment-related):

**Push Notification (FCM):**
- Due তৈরি হলে: *"এপ্রিল মাসের বেতন ৳১,৫০০ বকেয়া হয়েছে"*
- Payment নেওয়া হলে: *"আপনার পেমেন্ট ৳১,৫০০ গ্রহণ হয়েছে। ভাউচার: RCC-2025-0047"*
- 7 দিন আগে: *"এপ্রিল মাসের বেতনের শেষ তারিখ ৭ দিন বাকি"*

**SMS (SSL Wireless):**
- Same triggers as FCM

**In-app notification center:**
```
💳 মার্চ মাসের পেমেন্ট গৃহীত — ৳১,৫০০  [ভাউচার দেখুন]
⚠️ এপ্রিল মাসের বেতন বকেয়া — ৳১,৫০০  [দেখুন]
```

---

# 🔧 KEY IMPLEMENTATION NOTES

## PaymentService (Dart) — Core Logic:

```dart
class PaymentService {
  // পেমেন্ট নেওয়া (main method)
  Future<PaymentLedger> recordPayment({
    required String studentId,
    required String courseId,
    required String paymentTypeId,
    DateTime? forMonth,
    required double amountDue,
    required double amountPaid,
    double discountAmount = 0,
    double fineAmount = 0,
    required String paymentMethod,
    String? transactionRef,
    String? note,
    String? description,
  }) async {
    // 1. Insert to payment_ledger → voucher_no auto-generated by trigger
    // 2. Update payment_schedule status (paid/partial)
    // 3. Handle advance balance if overpaid
    // 4. Generate PDF voucher
    // 5. Send FCM push notification
    // 6. Send SMS
    // 7. Return ledger record
  }

  // মাসিক Due Generate
  Future<void> generateMonthlyDues({required DateTime month, String? courseId}) async {
    // Fetch active enrollments with course fee
    // Upsert payment_schedule (ignore if exists)
    // Send due notifications
  }
}
```

## Amount in Bengali Words:
```dart
String amountToWords(double amount) {
  // ১,৫০০ → "এক হাজার পাঁচশত টাকা মাত্র"
  // Custom implementation for Bengali
}
```

## Voucher PDF (pdf dart package):
```dart
Future<Uint8List> generateVoucher(PaymentLedger ledger, UserModel student, CourseModel course) async {
  final pdf = pw.Document();
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    build: (ctx) => pw.Column(children: [
      // Header: RADIANCE COACHING CENTER
      // Divider
      // Voucher No + Date
      // Student info (name, ID, course)
      // Divider
      // Fee type, amount, words, method
      // Partial notice (if applicable)
      // Divider
      // QR code + Signature line + Thank you
    ]),
  ));
  return pdf.save();
}
```

---

# 📊 KEY SQL QUERIES

```sql
-- এই মাসের বকেয়া list (due report)
SELECT u.full_name_bn, u.phone, c.name, ps.amount,
       CURRENT_DATE - ps.due_date AS overdue_days
FROM payment_schedule ps
JOIN users u ON ps.student_id = u.id
JOIN courses c ON ps.course_id = c.id
WHERE DATE_TRUNC('month', ps.for_month) = DATE_TRUNC('month', CURRENT_DATE)
  AND ps.status IN ('pending','partial')
  AND ps.payment_type_code = 'monthly'
ORDER BY overdue_days DESC NULLS LAST;

-- Fee type breakdown এই মাসে
SELECT pt.name_bn, COUNT(*) AS count, SUM(pl.amount_paid) AS collected
FROM payment_ledger pl
JOIN payment_types pt ON pl.payment_type_id = pt.id
WHERE DATE_TRUNC('month', pl.paid_at) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY pt.name_bn ORDER BY collected DESC;

-- একজন student-এর সব হিসাব (annual)
SELECT 
  TO_CHAR(DATE_TRUNC('month', ps.for_month), 'Month YYYY') AS month,
  pt.name_bn AS fee_type,
  ps.amount AS due,
  COALESCE(SUM(pl.amount_paid), 0) AS paid,
  ps.status
FROM payment_schedule ps
JOIN payment_types pt ON ps.payment_type_id = pt.id
LEFT JOIN payment_ledger pl ON pl.student_id = ps.student_id
  AND pl.payment_type_id = ps.payment_type_id
  AND COALESCE(pl.for_month, ps.for_month) = ps.for_month
WHERE ps.student_id = 'STUDENT_UUID'
  AND EXTRACT(YEAR FROM COALESCE(ps.for_month, ps.created_at)) = 2025
GROUP BY ps.id, pt.name_bn, month
ORDER BY ps.for_month DESC;

-- Last 12 months revenue (chart data)
SELECT TO_CHAR(DATE_TRUNC('month', paid_at), 'Mon YY') AS month,
       SUM(amount_paid) AS total
FROM payment_ledger
WHERE paid_at >= NOW() - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', paid_at)
ORDER BY DATE_TRUNC('month', paid_at);
```

---

# ✅ COMPLETE FEATURE CHECKLIST

## Admin ✅
- [ ] Payment Dashboard (summary + breakdown + charts)
- [ ] Add Payment — all 6 fee types
- [ ] Multi-fee collection (admission+monthly+material at once)
- [ ] Monthly fee — single month + multiple overdue months
- [ ] Material / Exam / Special fee with custom description
- [ ] Fine collection
- [ ] Partial payment support
- [ ] Advance payment / credit balance
- [ ] Discount rules setup
- [ ] Student discount assignment (permanent / temporary)
- [ ] Auto monthly due generation (Edge Function cron)
- [ ] Manual due generation per course/month
- [ ] Due list with overdue days + color coding
- [ ] Bulk SMS reminder to all overdue
- [ ] Student payment history (full, all types, all years)
- [ ] Edit/void a payment (admin only)
- [ ] Voucher PDF auto-generation on payment
- [ ] Partial voucher with remaining amount
- [ ] Voucher print (Bluetooth thermal printer)
- [ ] Voucher share (WhatsApp PDF)
- [ ] Voucher share as image
- [ ] Voucher download to phone
- [ ] Voucher reprint from history
- [ ] Monthly collection report (PDF + CSV)
- [ ] Due report (PDF)
- [ ] Student annual report (PDF)
- [ ] Revenue charts (12 months, fee type breakdown)
- [ ] Fee configuration settings
- [ ] Payment method settings
- [ ] Voucher template customization
- [ ] SMS template management
- [ ] Auto SMS on payment + on due creation

## Student ✅
- [ ] Dashboard payment widget (current due + last payment)
- [ ] Current due with payment instructions (bKash/Nagad number)
- [ ] Full payment history (all types, filterable by year/type)
- [ ] Per-payment status: Paid / Partial / Due color coding
- [ ] Voucher view (in-app PDF)
- [ ] Voucher download
- [ ] Voucher share
- [ ] Push notification: payment confirmed
- [ ] Push notification: due created
- [ ] Push notification: due reminder (7 days before)
- [ ] SMS notification (same triggers)
- [ ] Advance balance display (if any)
