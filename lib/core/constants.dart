/// App-wide and Supabase table name constants.
///
/// Table names match project rules and database migrations.
const String kAppName = 'Radiance';
const String kStudentIdPrefix = 'RCC';

/// [User.appMetadata] / [User.userMetadata] role values (Supabase Auth).
const String kRoleAdmin = 'admin';
const String kRoleStudent = 'student';
const String kRoleTeacher = 'teacher';

/// Supabase Auth email for students: `{11-digit BD phone}@student.radiance.local`.
/// Must match Edge Function `create-student` and [studentAuthEmailFromPhone].
const String kStudentAuthEmailDomain = 'student.radiance.local';

/// Login identifier for students (same string stored in Auth email field).
String studentAuthEmailFromPhone(String phoneDigits11) {
  final d = phoneDigits11.replaceAll(RegExp(r'\D'), '');
  return '$d@$kStudentAuthEmailDomain';
}

/// Default student password rule: last 9 digits of the 11-digit mobile number.
String studentPasswordFromPhoneDigits(String phoneDigits11) {
  final d = phoneDigits11.replaceAll(RegExp(r'\D'), '');
  if (d.length < 9) {
    throw FormatException('Invalid phone for password');
  }
  return d.substring(d.length - 9);
}

// --- Supabase public table names (Postgres) ---

/// Supabase Storage public bucket for course thumbnails (create in dashboard).
const String kStorageBucketThumbnails = 'thumbnails';

/// Supabase Storage bucket for user avatars (create in dashboard).
const String kStorageBucketAvatars = 'avatars';

/// Community chat attachments (images, PDFs; create in dashboard).
const String kStorageBucketCommunity = 'community';
const String kStorageBucketQbank = 'qbank';

const String kTableUsers = 'users';
const String kTableCourses = 'courses';
const String kTableSubjects = 'subjects';
const String kTableChapters = 'chapters';
const String kTableNotes = 'notes';
const String kTableEnrollments = 'enrollments';
const String kTablePayments = 'payments';
const String kTablePaymentDues = 'payment_dues';
const String kTableAttendanceSessions = 'attendance_sessions';
const String kTableAttendanceRecords = 'attendance_records';
const String kTableAttendanceEditLog = 'attendance_edit_log';
const String kTableAttendanceSettings = 'attendance_settings';
const String kTableExams = 'exams';
const String kTableQuestions = 'questions';
const String kTableExamSubmissions = 'exam_submissions';
const String kTableResults = 'results';
const String kTableQbankQuestions = 'qbank_questions';
const String kTableQbankBookmarks = 'qbank_bookmarks';
const String kTableQbankSessions = 'qbank_sessions';
const String kTableQbankSubjects = 'qbank_subjects';
const String kTableQbankChapters = 'qbank_chapters';
const String kTableQbankMcq = 'qbank_mcq';
const String kTableQbankCq = 'qbank_cq';
const String kTableQbankBookmarksV2 = 'qbank_bookmarks_v2';
const String kTableQbankPracticeSessions = 'qbank_practice_sessions';
const String kTableQbankPracticeAnswers = 'qbank_practice_answers';
const String kTableNotifications = 'notifications';
const String kTableSmsLogs = 'sms_logs';
const String kTableCommunityGroups = 'community_groups';
const String kTableCommunityMembers = 'community_members';
const String kTableCommunityMessages = 'community_messages';
const String kTableComplaints = 'complaints';
const String kTableHomeContent = 'home_content';
const String kTableSuggestions = 'suggestions';
const String kTableSuggestionLikes = 'suggestion_likes';
const String kTableDoubts = 'doubts';
@Deprecated('Use kTableDoubts')
const String kTableDoubtThreads = kTableDoubts;
const String kTableDoubtMessages = 'doubt_messages';
const String kTableStudentDoubtStats = 'student_doubt_stats';
const String kTableFeeServices = 'fee_services';
const String kTablePaymentTypes = 'payment_types';
const String kTablePaymentLedger = 'payment_ledger';
const String kTablePaymentSchedule = 'payment_schedule';
const String kTableDiscountRules = 'discount_rules';
const String kTableStudentDiscounts = 'student_discounts';
const String kTableAdvanceBalance = 'advance_balance';
const String kTablePaymentSettings = 'payment_settings';
const String kTableSmsTemplates = 'sms_templates';
