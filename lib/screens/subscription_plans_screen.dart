import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  int _selectedPlanIndex = -1; // -1 means no plan is selected initially
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user?.subscriptionExpiry != null) {
        setState(() {
          _remainingTime = authProvider.user!.subscriptionExpiry!.difference(
            DateTime.now(),
          );
          if (_remainingTime.isNegative) {
            _remainingTime = Duration.zero;
            authProvider.checkSubscription();
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00d : 00h : 00m : 00s";
    String days = duration.inDays.toString().padLeft(2, '0');
    String hours = (duration.inHours % 24).toString().padLeft(2, '0');
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "${days}d : ${hours}h : ${minutes}m : ${seconds}s";
  }

  void _showTermsAndConditions(
    BuildContext context,
    String planName,
    int months,
  ) {
    bool isChecked = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0F1424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please review the terms for $planName pack',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '1. Subscription Access: By subscribing to the $planName pack, you will gain full access to all premium features of PulseTrack for a period of $months month(s).\n\n'
                        '2. Billing: This is a one-time activation for demonstration purposes. In a real application, you would be charged via your selected payment method.\n\n'
                        '3. No Refunds: Subscription fees are non-refundable once the premium features are activated.\n\n'
                        '4. Usage: You agree to use the premium features in accordance with our fair use policy. Any misuse may lead to account suspension.\n\n'
                        '5. Data Privacy: Your health data remains encrypted and is only used to provide you with personalized insights.\n\n'
                        '6. Expiry: The pack will automatically expire after $months month(s). You can re-subscribe anytime after expiry.\n\n'
                        '7. Accuracy: PulseTrack is not a medical device. Insights provided are for informational purposes only.\n\n'
                        '8. Agreement: By ticking the box below, you acknowledge that you have read and agree to these terms.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      border: const Border(
                        top: BorderSide(color: Colors.white10),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (val) {
                                setModalState(() => isChecked = val ?? false);
                              },
                              activeColor: Colors.blueAccent,
                              side: const BorderSide(color: Colors.white30),
                            ),
                            const Expanded(
                              child: Text(
                                'I agree to the Terms & Conditions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isChecked
                                ? () {
                                    Navigator.pop(context);
                                    _activatePlan(planName, months);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              disabledBackgroundColor: Colors.grey.withOpacity(
                                0.2,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _getPlanRank(String? planName) {
    if (planName == null) return 0;
    if (planName.contains('1 Month')) return 1;
    if (planName.contains('6 Months')) return 2;
    if (planName.contains('12 Months')) return 3;
    return 0;
  }

  void _activatePlan(String planName, int months) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUpgrade = authProvider.user?.subscriptionType != null;
    authProvider.subscribeToPlan(planName, months);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isUpgrade
              ? '$planName Plan Upgraded Successfully!'
              : '$planName Pack Activated Successfully!',
        ),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {
      _selectedPlanIndex = -1; // Reset selection after upgrade
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isSubscribed = user?.subscriptionType != null;
    final currentPlanRank = _getPlanRank(user?.subscriptionType);

    return Scaffold(
      backgroundColor: const Color(0xFF000510), // Very dark navy/black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Membership Plans',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              // Active Subscription Status
              if (isSubscribed) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueAccent.withOpacity(0.2),
                        Colors.purpleAccent.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ACTIVE PLAN',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user!.subscriptionType!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.verified,
                            color: Colors.blueAccent,
                            size: 40,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Time Remaining',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            _formatDuration(_remainingTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize:
                                  14, // Reduced font size for longer string
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // Logo and Header
              if (!isSubscribed) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.diamond,
                      color: Colors.blueAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'PulseTrack',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(text: 'Choose the plan that\'s '),
                      TextSpan(
                        text: 'right for you',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlock premium features and take your heart health to the next level.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 40),
              ],

              // Pricing Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _buildPricingCard(
                        title: '1 Month',
                        price: '₹299',
                        period: '/mo',
                        description: 'Basic monthly access',
                        icon: Icons.calendar_today,
                        color: Colors.blue.withOpacity(0.8),
                        isSelected: _selectedPlanIndex == 0,
                        onTap: () => setState(() => _selectedPlanIndex = 0),
                        onSubscribe: () =>
                            _showTermsAndConditions(context, '1 Month', 1),
                        isUpgrade: isSubscribed,
                        isDisabled: currentPlanRank >= 1,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: _buildPricingCard(
                        title: '6 Months',
                        price: '₹599',
                        period: '/6 mo',
                        description: 'Most popular choice',
                        icon: Icons.calendar_month,
                        color: Colors.blueAccent,
                        isSelected: _selectedPlanIndex == 1,
                        onTap: () => setState(() => _selectedPlanIndex = 1),
                        onSubscribe: () =>
                            _showTermsAndConditions(context, '6 Months', 6),
                        isUpgrade: isSubscribed,
                        isDisabled: currentPlanRank >= 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: _buildPricingCard(
                        title: '12 Months',
                        price: '₹999',
                        period: '/year',
                        description: 'Best value for money',
                        icon: Icons.event_available,
                        color: Colors.amber,
                        isSelected: _selectedPlanIndex == 2,
                        onTap: () => setState(() => _selectedPlanIndex = 2),
                        onSubscribe: () =>
                            _showTermsAndConditions(context, '12 Months', 12),
                        isUpgrade: isSubscribed,
                        isDisabled: currentPlanRank >= 3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // Comparison Table Section
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.diamond,
                          color: Colors.blueAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'PulseTrack Plans Comparison',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildComparisonTable(context, _selectedPlanIndex),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // Bottom Features
              _buildBottomFeatures(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback? onTap,
    required VoidCallback onSubscribe,
    bool isUpgrade = false,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDisabled
                ? const Color(0xFF0A0E1A)
                : const Color(0xFF0F1424),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? Colors.blueAccent
                  : Colors.white.withOpacity(0.05),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              if (isSelected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.blueAccent, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'SELECTED',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? color : Colors.white70,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          icon,
                          color: isSelected ? color : Colors.white30,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          period,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isDisabled
                            ? null
                            : (isSelected ? onSubscribe : onTap),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.blueAccent
                              : const Color(0xFF1A1F2E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isDisabled
                              ? 'Current Plan'
                              : (isSelected
                                    ? (isUpgrade
                                          ? 'Upgrade Plan'
                                          : 'Subscribe Now')
                                    : 'Select Plan'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        description,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context, int selectedIndex) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(dividerColor: Colors.white.withOpacity(0.05)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              // Table Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 160,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1A2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Feature',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _PlanHeader(
                        icon: Icons.workspace_premium,
                        title: '1 Month',
                        isSelected: selectedIndex == 0,
                      ),
                    ),
                    Expanded(
                      child: _PlanHeader(
                        icon: Icons.workspace_premium,
                        title: '6 Months',
                        isSelected: selectedIndex == 1,
                      ),
                    ),
                    Expanded(
                      child: _PlanHeader(
                        icon: Icons.workspace_premium,
                        title: '12 Months',
                        isSelected: selectedIndex == 2,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),

              // Rows
              _buildCustomRow(
                'Price',
                ['₹299/mo', '₹599 (6 mo)', '₹999/yr'],
                Icons.sell,
                Colors.blue,
                selectedIndex,
              ),
              _buildCustomRow(
                'Heart Scans',
                ['Unlimited', 'Unlimited', 'Unlimited'],
                Icons.favorite,
                Colors.redAccent,
                selectedIndex,
              ),
              _buildCustomRow(
                'Ads',
                ['No', 'No', 'No'],
                Icons.block,
                Colors.orange,
                selectedIndex,
                isNegative: true,
              ),
              _buildCustomRow(
                'Basic BPM Result',
                [true, true, true],
                Icons.show_chart,
                Colors.blueAccent,
                selectedIndex,
              ),
              _buildCustomRow(
                'Advanced Analytics',
                [true, true, true],
                Icons.analytics,
                Colors.blue,
                selectedIndex,
              ),
              _buildCustomRow(
                'Stress Detection',
                ['Basic', 'Advanced', 'Advanced'],
                Icons.psychology,
                Colors.blueAccent,
                selectedIndex,
              ),
              _buildCustomRow(
                'History',
                ['30 days', '6 months', '12 months'],
                Icons.history,
                Colors.blue,
                selectedIndex,
              ),
              _buildCustomRow(
                'Health Goals',
                [false, true, true],
                Icons.track_changes,
                Colors.greenAccent,
                selectedIndex,
              ),
              _buildCustomRow(
                'Breathing Exercises',
                [false, true, true],
                Icons.air,
                Colors.blueAccent,
                selectedIndex,
              ),
              _buildCustomRow(
                'Smart Alerts',
                [false, true, true],
                Icons.notifications_active,
                Colors.amber,
                selectedIndex,
              ),
              _buildCustomRow(
                'AI Insights',
                [false, false, true],
                Icons.auto_awesome,
                Colors.purpleAccent,
                selectedIndex,
              ),
              _buildCustomRow(
                'Export Reports (PDF)',
                [false, false, true],
                Icons.picture_as_pdf,
                Colors.blue,
                selectedIndex,
              ),
              _buildCustomRow(
                'Sleep Tracking',
                [false, false, true],
                Icons.nightlight_round,
                Colors.blueAccent,
                selectedIndex,
              ),
              _buildCustomRow(
                'Priority Support',
                [false, false, true],
                Icons.headset_mic,
                Colors.orange,
                selectedIndex,
              ),
              _buildCustomRow(
                'Security',
                ['Basic', 'Advanced', 'Premium'],
                Icons.security,
                Colors.blueAccent,
                selectedIndex,
                showDivider: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomRow(
    String feature,
    List<dynamic> values,
    IconData icon,
    Color iconColor,
    int selectedIndex, {
    bool isNegative = false,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ), // Vertical padding handled by Container height
          child: Row(
            children: [
              SizedBox(
                width: 160,
                height:
                    48, // Fixed height for rows to ensure consistent highlighting
                child: Row(
                  children: [
                    Icon(icon, color: iconColor, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      feature,
                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                    ),
                  ],
                ),
              ),
              ...values.asMap().entries.map((entry) {
                final idx = entry.key;
                final v = entry.value;
                final isColSelected = idx == selectedIndex;

                return Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isColSelected
                          ? Colors.blueAccent.withOpacity(0.08)
                          : Colors.transparent,
                      border: isColSelected
                          ? Border(
                              left: BorderSide(
                                color: Colors.blueAccent.withOpacity(0.2),
                                width: 1,
                              ),
                              right: BorderSide(
                                color: Colors.blueAccent.withOpacity(0.2),
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                    child: Center(
                      child: _buildValueWidget(v, isNegative: isNegative),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (showDivider) const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  Widget _buildValueWidget(dynamic value, {bool isNegative = false}) {
    if (value is bool) {
      return Icon(
        value ? Icons.check_circle : Icons.cancel,
        color: value ? Colors.greenAccent : Colors.redAccent,
        size: 18,
      );
    }
    if (isNegative && value == 'No') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cancel, color: Colors.redAccent, size: 14),
          const SizedBox(width: 4),
          const Text('No', style: TextStyle(color: Colors.white, fontSize: 11)),
        ],
      );
    }
    return Text(
      value.toString(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildBottomFeatures() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildBottomFeatureItem(
          Icons.verified_user,
          'Secure Payments',
          '100% safe & secure',
        ),
        _buildBottomFeatureItem(
          Icons.currency_exchange,
          'Cancel Anytime',
          'No hidden charges',
        ),
        _buildBottomFeatureItem(
          Icons.headset_mic,
          '24x7 Support',
          'We\'re here to help',
        ),
        _buildBottomFeatureItem(
          Icons.lock,
          'Your Data is Safe',
          'Privacy guaranteed',
        ),
      ],
    );
  }

  Widget _buildBottomFeatureItem(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;

  const _PlanHeader({
    required this.icon,
    required this.title,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blueAccent.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: isSelected
            ? const BorderRadius.vertical(top: Radius.circular(10))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.blueAccent,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.blueAccent,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
