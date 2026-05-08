import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;
  int _refreshCounter = 0;

  void _handleScanComplete() {
    setState(() {
      _selectedIndex = 0;
      _refreshCounter++;
    });
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryRed : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryRed : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0 
          ? HomeScreen(
              key: ValueKey('home_$_refreshCounter'),
              onScanComplete: _handleScanComplete,
            )
          : _selectedIndex == 1 
              ? HistoryScreen(key: ValueKey('history_$_refreshCounter'))
              : const ProfileScreen(),
      floatingActionButton: Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryRed.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'main_nav_fab',
          onPressed: () => setState(() => _selectedIndex = 2),
          backgroundColor: _selectedIndex == 2 ? AppTheme.primaryRed : const Color(0xFF2A2E37),
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.backgroundColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        elevation: 10,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: _buildNavItem(0, Icons.home_rounded, 'Home')),
            const SizedBox(width: 80), // Space for the center Profile FAB
            Expanded(child: _buildNavItem(1, Icons.bar_chart_rounded, 'History')),
          ],
        ),
      ),
    );
  }
}
