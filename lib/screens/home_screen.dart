import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'ble_scan_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface => _isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get _border => _isDark ? AppColors.borderDark : AppColors.border;
  Color get _bg => _isDark ? AppColors.backgroundDark : AppColors.background;

  static const _titles = ['Dashboard', 'Configuration', 'Test'];

  Widget get _page {
    switch (_idx) {
      case 0:
        return const _DashboardPage();
      case 1:
        return const BleScanScreen(fromMenu: true);
      case 2:
        return const _ComingSoon(title: 'Test');
      default:
        return const _DashboardPage();
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _drawer() => Drawer(
        backgroundColor: _surface,
        child: Column(children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            color: AppColors.primary,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              const Text("EMEDGE",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2)),
              const Text("MASTERCONTROLLER",
                  style: TextStyle(
                      fontSize: 9, color: Colors.white70, letterSpacing: 2.5)),
            ]),
          ),

          const SizedBox(height: 8),

          _DItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            selected: _idx == 0,
            onTap: () {
              setState(() => _idx = 0);
              Navigator.pop(context);
            },
          ),
          _DItem(
            icon: Icons.settings_remote_rounded,
            label: 'Configuration',
            selected: _idx == 1,
            onTap: () {
              setState(() => _idx = 1);
              Navigator.pop(context);
            },
          ),
          _DItem(
            icon: Icons.science_rounded,
            label: 'Test',
            selected: _idx == 2,
            onTap: () {
              setState(() => _idx = 2);
              Navigator.pop(context);
            },
          ),

          const Spacer(),
          Divider(color: _border, height: 1),
          const SizedBox(height: 4),

          _DItem(
            icon: _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: _isDark ? 'Light Mode' : 'Dark Mode',
            selected: false,
            onTap: () {
              EVSEApp.of(context)?.toggleTheme();
              Navigator.pop(context);
            },
          ),
          _DItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            selected: false,
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
          const SizedBox(height: 12),
          Text("EMEDGE Systems Pvt. Ltd.",
              style: TextStyle(fontSize: 10, color: _textSecondary)),
          Text("v1.0.0", style: TextStyle(fontSize: 10, color: _textSecondary)),
          const SizedBox(height: 16),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      drawer: _drawer(),
      appBar: AppBar(
        backgroundColor: _surface,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(_titles[_idx]),
        actions: [
          IconButton(
            icon: Icon(
              _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: _textSecondary,
            ),
            onPressed: () => EVSEApp.of(context)?.toggleTheme(),
          ),
        ],
      ),
      body: _page,
    );
  }
}

// ── Drawer Item ───────────────────────────────────────────────────
class _DItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? AppColors.error
        : selected
            ? AppColors.primary
            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color)),
        selected: selected,
        selectedTileColor: AppColors.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.ev_station_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(height: 12),
                const Text("Welcome back",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Text("EMEDGE Dashboard",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text("Manage and monitor your EV chargers",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Row(children: [
            Expanded(
                child: _Stat(
                    icon: Icons.electrical_services_rounded,
                    label: "Chargers",
                    value: "—",
                    color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(
                child: _Stat(
                    icon: Icons.bolt_rounded,
                    label: "Active",
                    value: "—",
                    color: AppColors.success)),
            const SizedBox(width: 10),
            Expanded(
                child: _Stat(
                    icon: Icons.error_outline_rounded,
                    label: "Faults",
                    value: "—",
                    color: AppColors.error)),
          ]),
          const SizedBox(height: 16),

          // Coming soon notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border),
            ),
            child: Column(children: [
              Icon(Icons.construction_rounded,
                  size: 40, color: AppColors.primary.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text("Dashboard Coming Soon",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const SizedBox(height: 6),
              Text(
                "Real-time monitoring, energy analytics\n"
                "and fleet management will appear here.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textSec),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary)),
      ]),
    );
  }
}

// ── Coming Soon ───────────────────────────────────────────────────
class _ComingSoon extends StatelessWidget {
  final String title;
  const _ComingSoon({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.construction_rounded,
              color: AppColors.primary, size: 40),
        ),
        const SizedBox(height: 20),
        Text("$title — Coming Soon",
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
        const SizedBox(height: 8),
        Text(
          "This feature is under development\nand will be available soon.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary),
        ),
      ]),
    );
  }
}
