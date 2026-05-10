import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'edit_personal_info_screen.dart';
import 'health_goals_screen.dart';
import 'privacy_security_screen.dart';
import 'help_support_screen.dart';



class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 500,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      final bytes = await pickedFile.readAsBytes();
      final success = await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).updateProfileImage(bytes, pickedFile.name);

      setState(() => _isUploading = false);

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        final error = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to update profile image.')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Select Image Source',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.primaryRed,
              ),
              title: const Text(
                'Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryRed),
              title: const Text(
                'Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final String? profileImageUrl = user?.profileImage;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // User Info Card
              _buildUserInfoCard(user, profileImageUrl),
              const SizedBox(height: 16),

              // Overview Card
              _buildOverviewCard(),
              const SizedBox(height: 16),


              // Menu Items
              _buildMenuSection(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(user, String? profileImageUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121417),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[900],
                  backgroundImage: profileImageUrl != null
                      ? NetworkImage(
                          '${ApiService.baseUrl.replaceFirst('/api', '')}$profileImageUrl',
                        )
                      : null,
                  child: profileImageUrl == null
                      ? const Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryRed,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarqueeWidget(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? 'Arjun Sharma',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                MarqueeWidget(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user?.email ?? 'arjun.sharma@email.com',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user?.dob ?? 'Not set',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user?.gender ?? 'Not set',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return FutureBuilder<Map<String, dynamic>>(
      future: authProvider.getUserStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {'avgBpm': 0, 'maxBpm': 0, 'minBpm': 0, 'totalScans': 0};

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121417),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'All Time',
                        style: TextStyle(
                          color: AppTheme.primaryRed.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppTheme.primaryRed,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    Icons.favorite,
                    Colors.red,
                    '${stats['avgBpm']}',
                    'BPM',
                    'Avg. Heart Rate',
                  ),
                  _buildStatVerticalDivider(),
                  _buildStatItem(
                    Icons.show_chart,
                    Colors.pink,
                    '${stats['maxBpm']}',
                    'BPM',
                    'Max. Heart Rate',
                  ),
                  _buildStatVerticalDivider(),
                  _buildStatItem(
                    Icons.favorite_border,
                    Colors.blue,
                    '${stats['minBpm']}',
                    'BPM',
                    'Min. Heart Rate',
                  ),
                  _buildStatVerticalDivider(),
                  _buildStatItem(
                    Icons.center_focus_weak,
                    Colors.green,
                    '${stats['totalScans']}',
                    'Times',
                    'Scans Done',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String value,
    String unit,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildStatVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }


  Widget _buildMenuSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121417),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            Icons.person_outline,
            Colors.orange,
            'Personal Information',
            'Update your personal details',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditPersonalInfoScreen(),
                ),
              );
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            Icons.track_changes,
            Colors.purple,
            'Health Goals',
            'Set and track your health goals',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthGoalsScreen()),
              );
            },
          ),

          _buildMenuDivider(),
          _buildMenuItem(
            Icons.security_outlined,
            Colors.blue,
            'Privacy & Security',
            'Manage your privacy and security',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PrivacySecurityScreen()),
              );
            },
          ),

          _buildMenuDivider(),
          _buildMenuItem(
            Icons.help_outline,
            Colors.pink,
            'Help & Support',
            'Get help and contact support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
          ),
          _buildMenuDivider(),
          _buildMenuItem(
            Icons.logout,
            Colors.white54,
            'Log Out',
            'Sign out from your account',
            onTap: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    Color color,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap ?? () {},
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[500], fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildMenuDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(color: Colors.white.withOpacity(0.03), height: 1),
    );
  }
}

class MarqueeWidget extends StatefulWidget {
  final Widget child;
  final Axis direction;
  final Duration animationDuration, pauseDuration;
  final double gap;

  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = const Duration(milliseconds: 6000),
    this.pauseDuration = const Duration(milliseconds: 2000),
    this.gap = 50.0,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  late ScrollController scrollController;
  bool _showSecond = false;

  @override
  void initState() {
    scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback(scroll);
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void scroll(_) async {
    while (scrollController.hasClients) {
      if (scrollController.position.maxScrollExtent > 0) {
        if (!_showSecond) {
          setState(() => _showSecond = true);
          // Wait for the next frame so the second child is rendered and maxScrollExtent updated
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        await Future.delayed(widget.pauseDuration);
        if (scrollController.hasClients) {
          await scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: widget.animationDuration,
            curve: Curves.linear,
          );
        }
        if (scrollController.hasClients) {
          scrollController.jumpTo(0.0);
        }
      } else {
        if (_showSecond) {
          setState(() => _showSecond = false);
        }
        await Future.delayed(widget.pauseDuration);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: widget.direction,
      controller: scrollController,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.child,
          if (_showSecond) ...[
            SizedBox(width: widget.gap),
            widget.child,
          ],
        ],
      ),
    );
  }
}
