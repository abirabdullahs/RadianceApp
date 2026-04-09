import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../notifications/providers/unread_notifications_provider.dart';
import '../../widgets/admin_drawer.dart';

/// Admin posts a notice to all students enrolled in [courseId].
class AdminCourseNoticeScreen extends ConsumerStatefulWidget {
  const AdminCourseNoticeScreen({super.key, required this.courseId, this.courseName});

  final String courseId;
  final String? courseName;

  @override
  ConsumerState<AdminCourseNoticeScreen> createState() => _AdminCourseNoticeScreenState();
}

class _AdminCourseNoticeScreenState extends ConsumerState<AdminCourseNoticeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = _title.text.trim();
    final b = _body.text.trim();
    if (t.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শিরোনাম ও বিবরণ পূরণ করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final n = await ref.read(notificationsRepositoryProvider).sendCourseNotice(
            courseId: widget.courseId,
            title: t,
            body: b,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0 ? 'এই কোর্সে কোনো শিক্ষার্থী নেই' : '$n জনকে নোটিশ পাঠানো হয়েছে',
            style: GoogleFonts.hindSiliguri(),
          ),
        ),
      );
      if (n > 0) {
        _title.clear();
        _body.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.courseName?.trim();
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          name != null && name.isNotEmpty ? 'নোটিশ · $name' : 'কোর্স নোটিশ',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'নির্বাচিত কোর্সের সব এনরোল শিক্ষার্থীর অ্যাপে নোটিফিকেশন যাবে।',
            style: GoogleFonts.hindSiliguri(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            enabled: !_sending,
            decoration: InputDecoration(
              labelText: 'শিরোনাম',
              border: const OutlineInputBorder(),
              labelStyle: GoogleFonts.hindSiliguri(),
            ),
            style: GoogleFonts.hindSiliguri(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            enabled: !_sending,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: 'বিবরণ',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              labelStyle: GoogleFonts.hindSiliguri(),
            ),
            style: GoogleFonts.hindSiliguri(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('পাঠান', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
