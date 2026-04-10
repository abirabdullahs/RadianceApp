import 'dart:async';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/models/doubt_thread_model.dart';
import '../../../shared/models/user_model.dart';
import '../../admin/widgets/admin_drawer.dart';
import '../../admin/widgets/admin_responsive_scaffold.dart';
import '../../student/widgets/student_drawer.dart';
import '../../teacher/widgets/teacher_drawer.dart';
import '../repositories/doubt_repository.dart';

enum DoubtChatShell { student, teacher, admin }

/// Per-doubt chat: text, image, voice/file uploads; student can mark solved; purge with confirm.
class DoubtChatScreen extends ConsumerStatefulWidget {
  const DoubtChatScreen({
    super.key,
    required this.doubtId,
    required this.shell,
  });

  final String doubtId;
  final DoubtChatShell shell;

  @override
  ConsumerState<DoubtChatScreen> createState() => _DoubtChatScreenState();
}

class _DoubtChatScreenState extends ConsumerState<DoubtChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _repo = DoubtRepository();

  DoubtThreadModel? _thread;
  List<Map<String, dynamic>> _messages = [];
  final Map<String, UserModel> _senders = {};
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final t = await _repo.getThread(widget.doubtId);
      if (!mounted) return;
      setState(() {
        _thread = t;
        _loading = false;
      });
      if (t == null) return;
      final threadUsers = await _repo.loadUsersByIds([t.studentId]);
      if (!mounted) return;
      setState(() => _senders.addAll(threadUsers));
      final msgs = await _repo.listMessages(widget.doubtId);
      if (!mounted) return;
      setState(() => _messages = msgs);
      await _loadSenders(msgs);
      _scrollToBottom();
      _subscribe();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repo.streamMessages(widget.doubtId).listen((rows) {
      if (!mounted) return;
      final list = rows.map((e) => Map<String, dynamic>.from(e)).toList()
        ..sort((a, b) {
          final ta = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final tb = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return ta.compareTo(tb);
        });
      // Stream can emit [] before replication — don't wipe a good list.
      if (list.isEmpty && _messages.isNotEmpty) {
        unawaited(_refetchMessages());
        return;
      }
      setState(() => _messages = list);
      _loadSenders(list);
      _scrollToBottom();
    });
  }

  Future<void> _refetchMessages() async {
    try {
      final rows = await _repo.listMessages(widget.doubtId);
      if (!mounted) return;
      setState(() => _messages = rows);
      await _loadSenders(rows);
      _scrollToBottom();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _loadSenders(List<Map<String, dynamic>> msgs) async {
    final ids = msgs.map((m) => m['sender_id'] as String?).whereType<String>().toSet();
    final missing = ids.where((id) => !_senders.containsKey(id)).toList();
    if (missing.isEmpty) return;
    final map = await _repo.loadUsersByIds(missing);
    if (!mounted) return;
    setState(() => _senders.addAll(map));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget? _drawer() {
    switch (widget.shell) {
      case DoubtChatShell.student:
        return const StudentDrawer();
      case DoubtChatShell.teacher:
        return const TeacherDrawer();
      case DoubtChatShell.admin:
        return const AdminDrawer();
    }
  }

  Widget _chatShell({
    required Widget title,
    List<Widget>? actions,
    Widget? floatingActionButton,
    required Widget body,
  }) {
    if (widget.shell == DoubtChatShell.admin) {
      return AdminResponsiveScaffold(
        title: title,
        actions: actions,
        floatingActionButton: floatingActionButton,
        constrainBodyWidth: false,
        body: body,
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: _drawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: title,
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }

  Future<void> _sendText() async {
    final uid = supabaseClient.auth.currentUser?.id;
    if (uid == null || _sending) return;
    final t = _text.text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _repo.sendTextMessage(doubtId: widget.doubtId, text: t);
      if (!mounted) return;
      _text.clear();
      await _refetchMessages();
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

  Future<void> _upload({
    required Uint8List bytes,
    required String ext,
    required String messageType,
    String? caption,
  }) async {
    setState(() => _uploading = true);
    try {
      await _repo.uploadAndSendFile(
        doubtId: widget.doubtId,
        bytes: bytes,
        extension: ext,
        messageType: messageType,
        caption: caption,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('আপলোড ব্যর্থ: $e', style: GoogleFonts.hindSiliguri())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
        unawaited(_refetchMessages());
      }
    }
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final ext = x.path.split('.').last.toLowerCase();
    final safe = ext.length > 5 ? 'jpg' : ext;
    await _upload(bytes: bytes, ext: safe, messageType: 'image');
  }

  Future<void> _pickAudio() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m4a', 'mp3', 'aac', 'wav', 'ogg'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    Uint8List? bytes = f.bytes;
    bytes ??= f.path != null ? await File(f.path!).readAsBytes() : null;
    if (bytes == null) return;
    final name = f.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'm4a';
    await _upload(bytes: bytes, ext: ext, messageType: 'voice', caption: name);
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    Uint8List? bytes = f.bytes;
    bytes ??= f.path != null ? await File(f.path!).readAsBytes() : null;
    if (bytes == null) return;
    final name = f.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'pdf';
    await _upload(bytes: bytes, ext: ext, messageType: 'file', caption: name);
  }

  void _attachments(String uid) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('ছবি', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack_outlined),
              title: Text('অডিও / ভয়েস ফাইল', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(ctx);
                _pickAudio();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text('ফাইল', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markSolved() async {
    try {
      await _repo.markSolved(widget.doubtId);
      final t = await _repo.getThread(widget.doubtId);
      if (!mounted) return;
      setState(() => _thread = t);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('সমাধান চিহ্নিত হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
        );
      }
    }
  }

  Future<void> _purge() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('চ্যাট মুছবেন?', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text(
          'সব মেসেজ সার্ভার থেকে মুছে যাবে। আপনি কি নিশ্চিত?',
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('না', style: GoogleFonts.hindSiliguri())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('হ্যাঁ', style: GoogleFonts.hindSiliguri())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.purgeMessages(widget.doubtId);
      if (!mounted) return;
      setState(() => _messages = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('মেসেজ মুছে ফেলা হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e', style: GoogleFonts.hindSiliguri())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = supabaseClient.auth.currentUser?.id;
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return _chatShell(
        title: Text('চ্যাট', style: GoogleFonts.hindSiliguri()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_thread == null) {
      return _chatShell(
        title: Text('চ্যাট', style: GoogleFonts.hindSiliguri()),
        body: const Center(child: Text('পাওয়া যায়নি')),
      );
    }

    final t = _thread!;
    final studentName = _senders[t.studentId]?.fullNameBn ?? 'শিক্ষার্থী';

    final maxBodyW = min(MediaQuery.sizeOf(context).width, 720.0);

    return _chatShell(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.shell != DoubtChatShell.student ? studentName : 'সন্দেহ চ্যাট',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 17),
          ),
          Text(
            t.status == DoubtStatus.solved ? 'সমাধান হয়েছে' : 'খোলা',
            style: GoogleFonts.nunito(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        if (widget.shell == DoubtChatShell.student &&
            t.status == DoubtStatus.open &&
            t.studentId == uid)
          TextButton(
            onPressed: _markSolved,
            child: Text('সমাধান হয়েছে', style: GoogleFonts.hindSiliguri(color: Colors.white)),
          ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'purge') _purge();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'purge', child: Text('চ্যাট মুছুন', style: GoogleFonts.hindSiliguri())),
          ],
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBodyW),
          child: Column(
            children: [
              Material(
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('প্রশ্ন', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(t.problemDescription, style: GoogleFonts.hindSiliguri()),
                      if (t.problemImageUrl != null && t.problemImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(t.problemImageUrl!)),
                          child: CachedNetworkImage(
                            imageUrl: t.problemImageUrl!,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final own = m['sender_id'] == uid;
                        final sender = _senders[m['sender_id'] as String?];
                        final type = m['message_type'] as String? ?? 'text';
                        final body = m['body'] as String?;
                        final fileUrl = m['file_url'] as String?;
                        final bubbleMax = maxBodyW * 0.82;
                        return Align(
                          alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(maxWidth: bubbleMax),
                            decoration: BoxDecoration(
                              color: own ? scheme.primary.withValues(alpha: 0.15) : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!own)
                                  Text(
                                    sender?.fullNameBn ?? 'সদস্য',
                                    style: GoogleFonts.hindSiliguri(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                if (type == 'text')
                                  SelectableText(body ?? '', style: GoogleFonts.hindSiliguri()),
                                if (type == 'image' && fileUrl != null)
                                  CachedNetworkImage(imageUrl: fileUrl, height: 160, fit: BoxFit.cover),
                                if ((type == 'voice' || type == 'file') && fileUrl != null)
                                  InkWell(
                                    onTap: () => launchUrl(Uri.parse(fileUrl)),
                                    child: Text(
                                      body ?? 'ফাইল খুলুন',
                                      style: GoogleFonts.hindSiliguri(
                                        color: scheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (_uploading)
                      const ColoredBox(
                        color: Color(0x66000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
          if (uid != null)
            SafeArea(
              child: Material(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: _uploading ? null : () => _attachments(uid),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'মেসেজ…',
                            hintStyle: GoogleFonts.hindSiliguri(),
                            border: InputBorder.none,
                          ),
                          style: GoogleFonts.hindSiliguri(),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _sending ? null : _sendText,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
