import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_drawer.dart';
import '../../../../shared/models/user_model.dart';
import '../repositories/student_repository.dart';

final _studentListProvider =
    FutureProvider.autoDispose.family<List<UserModel>, String>((ref, query) async {
  return StudentRepository().getStudents(searchQuery: query.isEmpty ? null : query);
});

/// Searchable list of students → profile route.
class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_studentListProvider(_query));

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('শিক্ষার্থী', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/students/add'),
        backgroundColor: context.themePrimary,
        icon: const Icon(Icons.person_add),
        label: Text('নতুন', style: GoogleFonts.hindSiliguri()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'নাম / ফোন / আইডি দিয়ে খুঁজুন',
                hintStyle: GoogleFonts.hindSiliguri(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: GoogleFonts.hindSiliguri(),
              onSubmitted: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: async.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text('কোনো শিক্ষার্থী নেই', style: GoogleFonts.hindSiliguri()),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final u = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.themePrimary.withOpacity(0.15),
                        child: Text(
                          u.fullNameBn.isNotEmpty ? u.fullNameBn[0] : '?',
                          style: TextStyle(color: context.themePrimary),
                        ),
                      ),
                      title: Text(u.fullNameBn, style: GoogleFonts.hindSiliguri()),
                      subtitle: Text(
                        '${u.studentId ?? u.phone}',
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
                      onTap: () => context.push('/admin/students/${u.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}
