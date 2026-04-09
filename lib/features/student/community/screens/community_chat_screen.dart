import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';

/// Community group chat with Supabase Realtime (`community_messages` stream).
class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  StreamSubscription<List<Map<String, dynamic>>>? _msgSub;
  List<Map<String, dynamic>> _messages = [];
  final Map<String, UserModel> _senders = {};

  int _memberCount = 0;
  String? _groupDescription;
  bool _loadingMeta = true;

  Map<String, dynamic>? _replyingTo;
  bool _sending = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadGroupMeta();
    _subscribeMessages();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMeta() async {
    try {
      final group = await supabaseClient
          .from(kTableCommunityGroups)
          .select('description')
          .eq('id', widget.groupId)
          .maybeSingle();

      final members = await supabaseClient
          .from(kTableCommunityMembers)
          .select('user_id')
          .eq('group_id', widget.groupId);

      if (!mounted) return;
      setState(() {
        _groupDescription =
            group == null ? null : Map<String, dynamic>.from(group)['description'] as String?;
        _memberCount = (members as List<dynamic>).length;
        _loadingMeta = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMeta = false);
    }
  }

  void _subscribeMessages() {
    _msgSub?.cancel();
    _msgSub = supabaseClient
        .from(kTableCommunityMessages)
        .stream(primaryKey: const ['id'])
        .eq('group_id', widget.groupId)
        .order('created_at')
        .listen((rows) {
      if (!mounted) return;
      final filtered = rows
          .map((e) => Map<String, dynamic>.from(e))
          .where((m) => m['is_deleted'] != true)
          .toList();
      filtered.sort((a, b) {
        final ta = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      setState(() => _messages = filtered);
      _ensureSendersLoaded(filtered);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    });
  }

  Future<void> _ensureSendersLoaded(List<Map<String, dynamic>> messages) async {
    final ids = <String>{};
    for (final m in messages) {
      final sid = m['sender_id'] as String?;
      if (sid != null) ids.add(sid);
    }
    final missing = ids.where((id) => !_senders.containsKey(id)).toList();
    if (missing.isEmpty) return;

    try {
      final rows = await supabaseClient
          .from(kTableUsers)
          .select()
          .inFilter('id', missing);
      if (!mounted) return;
      setState(() {
        for (final raw in rows as List<dynamic>) {
          final u = UserModel.fromJson(Map<String, dynamic>.from(raw as Map));
          _senders[u.id] = u;
        }
      });
    } catch (_) {}
  }

  Map<String, dynamic>? _messageById(String? id) {
    if (id == null) return null;
    for (final m in _messages) {
      if (m['id'] == id) return m;
    }
    return null;
  }

  Map<String, dynamic>? get _pinnedMessage {
    final pinned = _messages.where((m) => m['is_pinned'] == true).toList();
    if (pinned.isEmpty) return null;
    pinned.sort((a, b) {
      final ta = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return pinned.first;
  }

  Future<void> _sendText(String uid) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await supabaseClient.from(kTableCommunityMessages).insert(<String, dynamic>{
        'group_id': widget.groupId,
        'sender_id': uid,
        'content': text,
        'type': 'text',
        'reply_to': _replyingTo?['id'],
      });
      if (!mounted) return;
      _textController.clear();
      setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('পাঠানো ব্যর্থ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _uploadAndSend({
    required String uid,
    required Uint8List bytes,
    required String extension,
    required String type,
    String? caption,
  }) async {
    setState(() => _uploading = true);
    try {
      final path = '${widget.groupId}/${_uuid.v4()}.$extension';
      await supabaseStorage.from(kStorageBucketCommunity).uploadBinary(
            path,
            bytes,
          );
      final publicUrl =
          supabaseStorage.from(kStorageBucketCommunity).getPublicUrl(path);

      await supabaseClient.from(kTableCommunityMessages).insert(<String, dynamic>{
        'group_id': widget.groupId,
        'sender_id': uid,
        'content': caption,
        'type': type,
        'file_url': publicUrl,
        'reply_to': _replyingTo?['id'],
      });
      if (!mounted) return;
      setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('আপলোড ব্যর্থ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImageGallery(String uid) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final ext = x.path.split('.').last.toLowerCase();
    final safe = ext.length > 5 ? 'jpg' : ext;
    await _uploadAndSend(
      uid: uid,
      bytes: bytes,
      extension: safe,
      type: 'image',
    );
  }

  Future<void> _pickFile(String uid) async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    Uint8List? bytes = f.bytes;
    bytes ??=
        f.path != null ? await File(f.path!).readAsBytes() : null;
    if (bytes == null) return;
    final name = f.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'pdf';
    await _uploadAndSend(
      uid: uid,
      bytes: bytes,
      extension: ext,
      type: 'file',
      caption: name,
    );
  }

  void _showAttachmentOptions(String uid) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('গ্যালারি থেকে ছবি', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageGallery(uid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text('ফাইল / PDF', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile(uid);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPinnedFull(Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    final type = msg['type']?.toString() ?? 'text';
    final url = msg['file_url']?.toString();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('পিন করা বার্তা', style: GoogleFonts.hindSiliguri()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type == 'image' && url != null && url.isNotEmpty)
                CachedNetworkImage(imageUrl: url),
              if (type == 'text' || (content.isNotEmpty && type != 'image'))
                SelectableText(content, style: GoogleFonts.hindSiliguri()),
              if (type == 'file' && url != null)
                TextButton(
                  onPressed: () => _openExternalUrl(url),
                  child: Text('খুলুন', style: GoogleFonts.hindSiliguri()),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('বন্ধ', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
  }

  void _showGroupInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.groupName, style: GoogleFonts.hindSiliguri()),
        content: Text(
          _groupDescription?.trim().isNotEmpty == true
              ? _groupDescription!
              : 'কোনো বিবরণ নেই।',
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ঠিক আছে', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    if (!await launchUrl(u, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('লিংক খোলা যায়নি')),
        );
      }
    }
  }

  void _openImageFullscreen(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onLongPressMessage(Map<String, dynamic> msg, String currentUid) {
    final senderId = msg['sender_id'] as String?;
    final isOwn = senderId == currentUid;
    final text = msg['content']?.toString() ?? '';
    final type = msg['type']?.toString() ?? 'text';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: Text('রিপ্লাই', style: GoogleFonts.hindSiliguri()),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text('কপি', style: GoogleFonts.hindSiliguri()),
              onTap: () async {
                Navigator.pop(ctx);
                final copyText = type == 'text'
                    ? text
                    : (msg['file_url']?.toString() ?? text);
                await Clipboard.setData(ClipboardData(text: copyText));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('কপি হয়েছে', style: GoogleFonts.hindSiliguri())),
                  );
                }
              },
            ),
            if (isOwn)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text(
                  'মুছুন',
                  style: GoogleFonts.hindSiliguri(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await supabaseClient
                        .from(kTableCommunityMessages)
                        .update(<String, dynamic>{'is_deleted': true})
                        .eq('id', msg['id'] as String);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic createdAt) {
    final dt = DateTime.tryParse(createdAt?.toString() ?? '');
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text('চ্যাট', style: GoogleFonts.hindSiliguri())),
            body: const Center(child: Text('লগইন প্রয়োজন')),
          );
        }
        final uid = user.id;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_loadingMeta)
                  Text(
                    '$_memberCount জন সদস্য',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: _showGroupInfo,
              ),
            ],
          ),
          body: Column(
            children: [
              if (_pinnedMessage != null)
                Material(
                  color: const Color(0xFFFFF9C4),
                  child: InkWell(
                    onTap: () => _showPinnedFull(_pinnedMessage!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.push_pin, size: 18, color: Color(0xFFF57F17)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _previewSnippet(_pinnedMessage!),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.hindSiliguri(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final sender = _senders[msg['sender_id'] as String?];
                        return _ChatBubble(
                          message: msg,
                          sender: sender,
                          isOwn: msg['sender_id'] == uid,
                          replyParent: msg['reply_to'] != null
                              ? _messageById(msg['reply_to'] as String)
                              : null,
                          formatTime: _formatTime,
                          onLongPress: () => _onLongPressMessage(msg, uid),
                          onTapImage: (url) => _openImageFullscreen(url),
                          onTapFile: _openExternalUrl,
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
              if (_replyingTo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _previewSnippet(_replyingTo!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hindSiliguri(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _replyingTo = null),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                child: Material(
                  elevation: 8,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.attach_file),
                          onPressed: _uploading || _sending
                              ? null
                              : () => _showAttachmentOptions(uid),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !_sending && !_uploading,
                            decoration: InputDecoration(
                              hintText: 'মেসেজ লিখুন...',
                              hintStyle: GoogleFonts.hindSiliguri(),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            style: GoogleFonts.hindSiliguri(),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: (_sending ||
                                  _uploading ||
                                  _textController.text.trim().isEmpty)
                              ? null
                              : () => _sendText(uid),
                          icon: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text('চ্যাট', style: GoogleFonts.hindSiliguri())),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text('চ্যাট', style: GoogleFonts.hindSiliguri())),
        body: Center(child: Text('$e')),
      ),
    );
  }

  String _previewSnippet(Map<String, dynamic> msg) {
    final type = msg['type']?.toString() ?? 'text';
    if (type == 'image') return '📷 ছবি';
    if (type == 'file') {
      return msg['content']?.toString().isNotEmpty == true
          ? '📎 ${msg['content']}'
          : '📎 ফাইল';
    }
    final c = msg['content']?.toString() ?? '';
    return c.isEmpty ? 'মেসেজ' : c;
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.sender,
    required this.isOwn,
    required this.replyParent,
    required this.formatTime,
    required this.onLongPress,
    required this.onTapImage,
    required this.onTapFile,
  });

  final Map<String, dynamic> message;
  final UserModel? sender;
  final bool isOwn;
  final Map<String, dynamic>? replyParent;
  final String Function(dynamic) formatTime;
  final VoidCallback onLongPress;
  final void Function(String url) onTapImage;
  final void Function(String url) onTapFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = message['type']?.toString() ?? 'text';
    final content = message['content']?.toString() ?? '';
    final fileUrl = message['file_url']?.toString();
    final isAdmin = sender?.role == UserRole.admin;

    Color bubbleColor;
    Alignment align;
    if (isOwn) {
      align = Alignment.centerRight;
      if (isAdmin) {
        bubbleColor = AppTheme.accent.withValues(alpha: 0.35);
      } else {
        bubbleColor = AppTheme.primary.withValues(alpha: 0.9);
      }
    } else {
      align = Alignment.centerLeft;
      if (isAdmin) {
        bubbleColor = AppTheme.accent.withValues(alpha: 0.25);
      } else {
        bubbleColor = theme.colorScheme.surfaceContainerHighest;
      }
    }

    final Color fg;
    if (isOwn && !isAdmin) {
      fg = theme.colorScheme.onPrimary;
    } else if (isOwn && isAdmin) {
      fg = const Color(0xFF1A1204);
    } else {
      fg = theme.colorScheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: align,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isOwn && sender != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin) ...[
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 16,
                              color: AppTheme.accent.darken(0.15),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              sender!.fullNameBn,
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (isOwn && isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 16,
                              color: AppTheme.accent.darken(0.2),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'অ্যাডমিন',
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (replyParent != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.outline,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          _replyPreviewText(replyParent!),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    if (type == 'image' &&
                        fileUrl != null &&
                        fileUrl.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => onTapImage(fileUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: fileUrl,
                            width: 220,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(
                              width: 220,
                              height: 140,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                        ),
                      ),
                      if (content.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (type == 'file' && fileUrl != null && fileUrl.isNotEmpty) ...[
                      InkWell(
                        onTap: () => onTapFile(fileUrl),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file, color: fg, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                content.isNotEmpty ? content : 'ফাইল',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 14,
                                  color: fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (type == 'text' && content.isNotEmpty)
                      SelectableText(
                        content,
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 15,
                          color: fg,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        formatTime(message['created_at']),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _replyPreviewText(Map<String, dynamic> parent) {
    final t = parent['type']?.toString() ?? 'text';
    if (t == 'image') return '📷 ছবি';
    if (t == 'file') {
      return parent['content']?.toString().isNotEmpty == true
          ? '📎 ${parent['content']}'
          : '📎 ফাইল';
    }
    return parent['content']?.toString() ?? '';
  }
}

extension on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
