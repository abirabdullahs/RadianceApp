import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations not found in context');
    return value!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _strings = {
    'bn': {
      'app_name': 'Radiance',
      'settings': 'সেটিংস',
      'edit_profile': 'প্রোফাইল সম্পাদনা',
      'name_address_photo': 'নাম, ঠিকানা, ছবি',
      'theme_and_colors': 'থিম ও রঙ',
      'choose_theme_colors': 'নীল, সবুজ, বেগুনি ইত্যাদি থেকে বাছাই করুন',
      'choose_theme': 'থিম বাছাই করুন',
      'change_color_mode': 'রঙের সেট ও লাইট/ডার্ক মোড এখান থেকে বদলান।',
      'color_theme': 'রঙের থিম',
      'display_mode': 'ডিসপ্লে মোড',
      'system_mode': 'সিস্টেম (ডিভাইস অনুযায়ী)',
      'light_mode': 'লাইট',
      'dark_mode': 'ডার্ক',
      'language': 'ভাষা',
      'choose_language': 'বাংলা বা ইংরেজি ভাষা নির্বাচন করুন',
      'bangla': 'বাংলা',
      'english': 'ইংরেজি',
      'change_password': 'পাসওয়ার্ড পরিবর্তন',
      'current_password': 'বর্তমান পাসওয়ার্ড',
      'new_password_min': 'নতুন পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)',
      'new_password_again': 'নতুন পাসওয়ার্ড আবার',
      'current_password_required': 'বর্তমান পাসওয়ার্ড দিন',
      'min_6_chars': 'কমপক্ষে ৬ অক্ষর',
      'not_matching': 'মিলছে না',
      'update_password': 'পাসওয়ার্ড আপডেট করুন',
      'password_changed': 'পাসওয়ার্ড পরিবর্তন হয়েছে',
      'failed': 'ব্যর্থ',
      'wrong_current_password': 'বর্তমান পাসওয়ার্ড ভুল',
      'new_password_not_same': 'নতুন পাসওয়ার্ড আগের মতো হতে পারবে না',
      'dashboard': 'ড্যাশবোর্ড',
      'my_courses': 'আমার কোর্স',
      'exams': 'পরীক্ষা',
      'results': 'ফলাফল',
      'payments': 'পেমেন্ট',
      'attendance': 'উপস্থিতি',
      'group_chat': 'গ্রুপ চ্যাট',
      'doubt_solve': 'সন্দেহ সমাধান',
      'question_bank': 'প্রশ্ন ব্যাংক',
      'logout': 'লগআউট',
      'student': 'শিক্ষার্থী',
      'id_prefix': 'আইডি',
      'home': 'হোম',
      'notification': 'নোটিফিকেশন',
      'chat': 'চ্যাট',
      'menu': 'মেনু',
    },
    'en': {
      'app_name': 'Radiance',
      'settings': 'Settings',
      'edit_profile': 'Edit Profile',
      'name_address_photo': 'Name, address, photo',
      'theme_and_colors': 'Theme & Colors',
      'choose_theme_colors': 'Pick from blue, green, purple and more',
      'choose_theme': 'Choose Theme',
      'change_color_mode': 'Change color set and light/dark mode from here.',
      'color_theme': 'Color Theme',
      'display_mode': 'Display Mode',
      'system_mode': 'System (follow device)',
      'light_mode': 'Light',
      'dark_mode': 'Dark',
      'language': 'Language',
      'choose_language': 'Choose Bangla or English',
      'bangla': 'Bangla',
      'english': 'English',
      'change_password': 'Change Password',
      'current_password': 'Current password',
      'new_password_min': 'New password (min 6 chars)',
      'new_password_again': 'Confirm new password',
      'current_password_required': 'Enter current password',
      'min_6_chars': 'Minimum 6 characters',
      'not_matching': 'Does not match',
      'update_password': 'Update Password',
      'password_changed': 'Password changed successfully',
      'failed': 'Failed',
      'wrong_current_password': 'Current password is incorrect',
      'new_password_not_same': 'New password cannot be same as old password',
      'dashboard': 'Dashboard',
      'my_courses': 'My Courses',
      'exams': 'Exams',
      'results': 'Results',
      'payments': 'Payments',
      'attendance': 'Attendance',
      'group_chat': 'Group Chat',
      'doubt_solve': 'Doubt Solving',
      'question_bank': 'Question Bank',
      'logout': 'Logout',
      'student': 'Student',
      'id_prefix': 'ID',
      'home': 'Home',
      'notification': 'Notification',
      'chat': 'Chat',
      'menu': 'Menu',
    },
  };

  String t(String key) {
    final lang = locale.languageCode == 'en' ? 'en' : 'bn';
    return _strings[lang]?[key] ?? _strings['bn']![key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['bn', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
