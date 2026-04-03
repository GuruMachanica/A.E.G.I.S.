import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../providers/navigation_provider.dart';
import 'home_screen.dart';
import 'call_history_screen.dart';
import 'profile_screen.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationProvider);

    return Scaffold(
      backgroundColor: bgPrimary,
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          CallHistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _AegisNavBar(
        currentIndex: index,
        onTap: (i) => ref.read(navigationProvider.notifier).setIndex(i),
      ),
    );
  }
}

class _AegisNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AegisNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgSurface,
        border: Border(top: BorderSide(color: inputBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.article_outlined,
                label: 'Logs',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active ? accentTeal : textMuted,
              size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: active ? accentTeal : textMuted,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
