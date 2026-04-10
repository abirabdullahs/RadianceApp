import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'student_drawer.dart';

class StudentBottomShell extends StatelessWidget {
  const StudentBottomShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int _selectedIndex() {
    if (location.startsWith('/student/notifications')) return 1;
    if (location.startsWith('/student/community')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    return Scaffold(
      key: scaffoldKey,
      drawer: const StudentDrawer(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              if (location != '/student') {
                context.go('/student');
              }
              break;
            case 1:
              if (!location.startsWith('/student/notifications')) {
                context.go('/student/notifications');
              }
              break;
            case 2:
              if (!location.startsWith('/student/community')) {
                context.go('/student/community');
              }
              break;
            case 3:
              scaffoldKey.currentState?.openDrawer();
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notification',
          ),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
    );
  }
}
