import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Use as [AppBar.leading] so [build] receives a context **under** [Scaffold].
/// Calling [appBarDrawerLeading] with the screen [State]'s context fails because
/// [Scaffold.maybeOf] only sees ancestors — the drawer button would stay hidden.
class AppBarDrawerLeading extends StatelessWidget {
  const AppBarDrawerLeading({super.key});

  @override
  Widget build(BuildContext context) {
    return appBarDrawerLeading(context);
  }
}

/// বাম পাশে: [পিছনে] (যদি স্ট্যাক থাকে) + [মেনু]। ডান দিকে আলাদা মেনু বাটন লাগবে না।
Widget appBarDrawerLeading(BuildContext context) {
  final scaffoldState = Scaffold.maybeOf(context);
  if (scaffoldState == null || !scaffoldState.hasDrawer) {
    return const SizedBox.shrink();
  }
  final canPop = context.canPop();
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (canPop)
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'পিছনে',
          onPressed: () => context.pop(),
        ),
      IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'মেনু',
        onPressed: () => scaffoldState.openDrawer(),
      ),
    ],
  );
}

/// [AppBar.leadingWidth] — দুই আইকনের জন্য যথেষ্ট জায়গা।
double leadingWidthForDrawer(BuildContext context) {
  return context.canPop() ? 112 : 56;
}
