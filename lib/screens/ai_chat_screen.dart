import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_advice_service.dart';
import '../theme/app_theme.dart';

import '../models/bpm_record.dart';

class AiChatScreen extends StatefulWidget {
  final BpmRecord? latestRecord;
  const AiChatScreen({super.key, this.latestRecord});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiAdviceService _aiService = AiAdviceService();

  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Hello! I\'m your PulseTrack Health Assistant 💓\n\nI can help you understand your heart rate, SpO2, and blood pressure readings. Ask me anything!'
    }
  ];

  bool _isLoading = false;
  bool _isOfflineMode = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Build vitals context for the AI
      String? vitalsContext;
      if (widget.latestRecord != null) {
        vitalsContext = 'The user\'s latest vitals are: '
            'Heart Rate: ${widget.latestRecord!.bpm} BPM, '
            'Oxygen: ${widget.latestRecord!.spo2 ?? "N/A"}%, '
            'Blood Pressure: ${widget.latestRecord!.systolic ?? "N/A"}/${widget.latestRecord!.diastolic ?? "N/A"} mmHg.';
      }

      // Call AI — pass history WITHOUT the empty placeholder
      final response = await _aiService.chatWithAi(
        text,
        _messages,
        vitalsContext: vitalsContext,
      );

      if (mounted) {
        // Detect if we fell through to offline mode
        final isOffline = response.contains('offline mode') ||
            response.contains('API limits');
        setState(() {
          _messages.add({'role': 'ai', 'text': response});
          _isLoading = false;
          if (isOffline) _isOfflineMode = true;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('CHATBOT UI ERROR: $e');
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text':
                'Sorry, something went wrong. Please check your internet connection and try again.'
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Health Assistant',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Powered by Gemini',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      body: Column(
        children: [
          // Offline mode notice
          if (_isOfflineMode)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI quota reached for today — using offline mode. Answers are pre-programmed.',
                      style: GoogleFonts.outfit(
                          color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // Quick-access chip suggestions
          if (_messages.length == 1)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('What is a normal BPM?'),
                    _buildChip('How does SpO2 work?'),
                    _buildChip('Why is my heart rate high?'),
                    _buildChip('Tips to reduce heart rate'),
                  ],
                ),
              ),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildMessage(msg['text']!, isUser);
              },
            ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF161A22),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 15),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask about your health...',
                        hintStyle: GoogleFonts.outfit(
                            color: Colors.white38, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isLoading ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: _isLoading
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF6C63FF),
                                Color(0xFF3B82F6)
                              ],
                            ),
                      color: _isLoading ? Colors.white12 : null,
                      shape: BoxShape.circle,
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _isLoading ? Colors.white24 : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryRed
                    : const Color(0xFF1E2430),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2430),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: _AnimatedDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          _controller.text = label;
          _sendMessage();
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: const Color(0xFF6C63FF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated Typing Dots ──────────────────────────────────────────────────────
class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.3 + 0.7 * _animations[i].value),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
