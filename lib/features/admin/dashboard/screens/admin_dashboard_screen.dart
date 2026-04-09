import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../providers/dashboard_provider.dart';
import '../repositories/dashboard_repository.dart';

/// Admin home: summary cards, charts, quick actions.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('অ্যাডমিন', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminDashboardProvider),
          ),
        ],
      ),
      drawer: _AdminDrawer(),
      body: async.when(
        data: (data) => _DashboardBody(data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'লোড করা যায়নি: $e',
              style: GoogleFonts.hindSiliguri(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: Text(
              'Radiance',
              style: GoogleFonts.hindSiliguri(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text('ড্যাশবোর্ড', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin');
            },
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: Text('কোর্স', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/courses');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text('শিক্ষার্থী', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/students');
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/payments');
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: Text('উপস্থিতি', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/attendance');
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz),
            title: Text('পরীক্ষা', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/exams');
            },
          ),
          ListTile(
            leading: const Icon(Icons.web),
            title: Text('হোম পেজ কন্টেন্ট', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/cms');
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardProvider);
        await ref.read(adminDashboardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _greetingLine(),
            style: GoogleFonts.hindSiliguri(fontSize: 16, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _SummaryCard(
                  title: 'মোট শিক্ষার্থী',
                  value: '${data.totalStudents}',
                  icon: Icons.people,
                ),
                _SummaryCard(
                  title: 'আজকের উপস্থিতি',
                  value: data.todayAttendancePct == null
                      ? '—'
                      : '${data.todayAttendancePct!.toStringAsFixed(0)}%',
                  icon: Icons.percent,
                ),
                _SummaryCard(
                  title: 'এই মাস আয়',
                  value: fmt.format(data.monthRevenue),
                  icon: Icons.account_balance_wallet,
                ),
                _SummaryCard(
                  title: 'আজকের পেমেন্ট',
                  value: '${data.todayPaymentsCount}',
                  icon: Icons.receipt_long,
                ),
                _SummaryCard(
                  title: 'পরীক্ষা (লাইভ/নির্ধারিত)',
                  value: '${data.upcomingExamsCount}',
                  icon: Icons.quiz,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'দ্রুত কাজ',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickChip(
                label: 'শিক্ষার্থী যোগ',
                icon: Icons.person_add,
                onTap: () => context.push('/admin/students/add'),
              ),
              _QuickChip(
                label: 'উপস্থিতি শুরু',
                icon: Icons.how_to_reg,
                onTap: () => context.push('/admin/attendance'),
              ),
              _QuickChip(
                label: 'পেমেন্ট',
                icon: Icons.add_card,
                onTap: () => context.push('/admin/payments/add'),
              ),
              _QuickChip(
                label: 'পরীক্ষা',
                icon: Icons.edit_note,
                onTap: () => context.push('/admin/exams'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'মাসিক আয় (৬ মাস)',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _RevenueBarChart(monthly: data.monthlyRevenue),
          ),
          const SizedBox(height: 24),
          Text(
            'উপস্থিতির ধারা (৭ দিন)',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _AttendanceLineChart(points: data.attendanceTrend),
          ),
          const SizedBox(height: 24),
          Text(
            'কোর্স অনুযায়ী শিক্ষার্থী',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _CoursePieChart(segments: data.courseDistribution),
          ),
        ],
      ),
    );
  }

  String _greetingLine() {
    final now = DateTime.now();
    final b = DateFormat.yMMMMd().format(now);
    return 'সুপ্রভাত, অ্যাডমিন! — $b';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 140,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppTheme.accent),
              Text(title, style: GoogleFonts.hindSiliguri(fontSize: 12)),
              Text(
                value,
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 20, color: AppTheme.primary),
      label: Text(label, style: GoogleFonts.hindSiliguri()),
      onPressed: onTap,
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({required this.monthly});

  final List<Map<String, dynamic>> monthly;

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return Center(child: Text('কোনো ডেটা নেই', style: GoogleFonts.hindSiliguri()));
    }
    final maxY = monthly
        .map((e) => (e['amount'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final top = maxY <= 0 ? 1.0 : maxY * 1.1;

    return BarChart(
      BarChartData(
        maxY: top,
        barGroups: [
          for (var i = 0; i < monthly.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (monthly[i]['amount'] as num?)?.toDouble() ?? 0,
                  color: AppTheme.primary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
                final label = monthly[i]['label'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _AttendanceLineChart extends StatelessWidget {
  const _AttendanceLineChart({required this.points});

  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(child: Text('কোনো ডেটা নেই', style: GoogleFonts.hindSiliguri()));
    }
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), (points[i]['pct'] as num?)?.toDouble() ?? 0),
            ],
            color: AppTheme.accent,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Text(
                  '${points[i]['label']}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _CoursePieChart extends StatelessWidget {
  const _CoursePieChart({required this.segments});

  final List<Map<String, dynamic>> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return Center(
        child: Text('নথিভুক্ত কোর্স নেই', style: GoogleFonts.hindSiliguri()),
      );
    }
    final total = segments.fold<double>(
      0,
      (a, s) => a + ((s['value'] as num?)?.toDouble() ?? 0),
    );
    if (total <= 0) {
      return Center(child: Text('০ জন', style: GoogleFonts.hindSiliguri()));
    }
    final colors = [
      AppTheme.primary,
      AppTheme.accent,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
      Colors.indigo,
    ];
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < segments.length; i++) {
      final v = (segments[i]['value'] as num?)?.toDouble() ?? 0;
      final pct = v / total;
      sections.add(
        PieChartSectionData(
          value: v,
          title: '${(pct * 100).toStringAsFixed(0)}%',
          color: colors[i % colors.length],
          radius: 80,
          titleStyle: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      );
      start += pct;
    }
    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 36,
        sectionsSpace: 2,
      ),
    );
  }
}
