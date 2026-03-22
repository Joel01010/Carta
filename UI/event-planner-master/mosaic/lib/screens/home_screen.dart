import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/sync_service.dart';
import '../widgets/neon_voice_orb.dart';
import '../widgets/itinerary_card.dart';
import '../widgets/timeline_route_widget.dart';
import '../widgets/local_sync_indicator.dart';
import '../widgets/glass_input_bar.dart';

// ---------------------------------------------------------------------------
// Chat message model
// ---------------------------------------------------------------------------
enum MessageRole { user, ai }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime time;
  ChatMessage({required this.text, required this.role, DateTime? time})
      : time = time ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// Sample itinerary data
// ---------------------------------------------------------------------------
const _sampleItems = [
  ItineraryItem(
    emoji: '🍔',
    title: 'Dinner at The Neon Diner',
    time: '7:00 PM',
    location: 'Downtown Arts District',
    isVerified: false,
    isSynced: true,
    category: 'food',
  ),
  ItineraryItem(
    emoji: '🎟️',
    title: 'Indie Night Live — The Groove Collective',
    time: '9:00 PM',
    location: 'Pulse Arena · Floor B',
    isVerified: true,
    isSynced: true,
    category: 'music',
  ),
  ItineraryItem(
    emoji: '🍸',
    title: 'After-hours at Sky Lounge',
    time: '11:30 PM',
    location: 'Rooftop, 24th Floor',
    isVerified: true,
    isSynced: false,
    category: 'nightlife',
  ),
  ItineraryItem(
    emoji: '🏞️',
    title: 'Morning Hike at Sunset Ridge',
    time: '8:00 AM',
    location: 'Sunset Ridge Trail',
    isVerified: false,
    isSynced: true,
    category: 'outdoor',
  ),
];

// ---------------------------------------------------------------------------
// Filter options
// ---------------------------------------------------------------------------
const _filterOptions = ['All', 'Food 🍔', 'Music 🎵', 'Nightlife 🍸', 'Outdoor 🏞️'];
const _filterKeys = ['all', 'food', 'music', 'nightlife', 'outdoor'];

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isListening = false;
  String _activeFilter = 'all';
  bool _isDragOver = false;

  final List<ItineraryItem> _dailyPlanItems = [
    const ItineraryItem(
      emoji: '🍔',
      title: 'Dinner at The Neon Diner',
      time: '7:00 PM',
      location: 'Downtown Arts District',
      isVerified: false,
      isSynced: true,
      category: 'food',
    ),
    const ItineraryItem(
      emoji: '🎟️',
      title: 'Indie Night Live — The Groove Collective',
      time: '9:00 PM',
      location: 'Pulse Arena · Floor B',
      isVerified: true,
      isSynced: true,
      category: 'music',
    ),
    const ItineraryItem(
      emoji: '🍸',
      title: 'After-hours at Sky Lounge',
      time: '11:30 PM',
      location: 'Rooftop, 24th Floor',
      isVerified: true,
      isSynced: false,
      category: 'nightlife',
    ),
  ];

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hey! I'm Carta 👋 Your city, mapped for you. What are we planning?",
      role: MessageRole.ai,
    ),
  ];

  List<ItineraryItem> get _filteredItems {
    if (_activeFilter == 'all') return _sampleItems;
    return _sampleItems.where((e) => e.category == _activeFilter).toList();
  }

  @override
  void initState() {
    super.initState();
    SyncService.instance.init();
  }

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    HapticFeedback.mediumImpact();
  }

  void _onMessageSubmitted(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, role: MessageRole.user));
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: _getAiResponse(text), role: MessageRole.ai));
      });
    });
  }

  String _getAiResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('dinner') || lower.contains('food') || lower.contains('eat')) {
      return "Great choice! 🍔 The Neon Diner is trending this weekend. I've saved a spot for 7 PM — want me to add it to your plan?";
    } else if (lower.contains('ticket') || lower.contains('event') || lower.contains('concert')) {
      return "🎟️ I found verified tickets for Indie Night Live at Pulse Arena. 100% authentic — shall I lock them in?";
    } else if (lower.contains('bar') || lower.contains('drink') || lower.contains('lounge')) {
      return '🍸 Sky Lounge is the perfect after-spot! Rooftop views, live DJ. Shall I add it?';
    }
    return "I'm on it! ✨ Let me scan the best options for your weekend. Check the Events Hub below!";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        const _BackgroundBlobs(),
        SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOrbSection(),
                    const SizedBox(height: 24),
                    _buildChatHistory(),
                    const SizedBox(height: 32),
                    _buildEventsHub(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildInputBar(),
          ]),
        ),
      ]),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
              children: const [
                TextSpan(text: 'Car', style: TextStyle(color: AppColors.neonBlue)),
                TextSpan(text: 'ta', style: TextStyle(color: AppColors.deepBlue)),
              ],
            ),
          ),
          const LocalSyncIndicator(),
        ],
      ),
    );
  }

  // ── Orb ─────────────────────────────────────────────────────────────────
  Widget _buildOrbSection() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Text("Your city, mapped for you.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            "I've mapped out some weekend ideas based on your taste. Where should we start?",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.textSecondary, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        NeonVoiceOrb(isListening: _isListening, onTap: _toggleListening),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isListening
              ? Text('Listening…',
                  key: const ValueKey('listening'),
                  style: GoogleFonts.outfit(
                    color: AppColors.neonBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ))
              : Text('Tap orb to speak',
                  key: const ValueKey('idle'),
                  style: GoogleFonts.outfit(
                      color: AppColors.textSecondary, fontSize: 13)),
        ),
      ]),
    );
  }

  // ── Chat History ────────────────────────────────────────────────────────
  Widget _buildChatHistory() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        child: Row(children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                  color: AppColors.neonBlue,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('Chat with Carta',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              )),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
            children: _messages.map((msg) => _ChatBubble(message: msg)).toList()),
      ),
    ]);
  }

  // ── Events Hub ──────────────────────────────────────────────────────────
  Widget _buildEventsHub() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(children: [
                Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                        color: AppColors.neonBlue,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('Events Hub',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    )),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('This Weekend',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),

      // Filter chips
      SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20, right: 8),
          itemCount: _filterOptions.length,
          itemBuilder: (ctx, i) {
            final key = _filterKeys[i];
            final label = _filterOptions[i];
            final isActive = _activeFilter == key;
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.neonBlue.withValues(alpha: 0.1)
                      : AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppColors.neonBlue
                        : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(
                            color: AppColors.neonBlue.withValues(alpha: 0.3),
                            blurRadius: 8)]
                      : [],
                ),
                child: Text(label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    )),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 14),

      // Horizontal event cards
      SizedBox(
        height: 220,
        child: _filteredItems.isEmpty
            ? Center(
                child: Text('No events in this category',
                    style: GoogleFonts.outfit(
                        color: AppColors.textSecondary, fontSize: 13)))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 8),
                itemCount: _filteredItems.length,
                itemBuilder: (ctx, i) =>
                    ItineraryCard(item: _filteredItems[i]),
              ),
      ),

      const SizedBox(height: 28),

      // Divider
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              AppColors.neonBlue.withValues(alpha: 0.4),
              Colors.transparent,
            ]),
          ),
        ),
      ),

      const SizedBox(height: 24),

      // Daily Plan header
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
        child: Row(children: [
          Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                  color: AppColors.deepBlue,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('Daily Plan',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 8),
          Flexible(
            child: Text('— drag events here',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    color: AppColors.textSecondary, fontSize: 11)),
          ),
        ]),
      ),

      // DragTarget wrapping timeline
      DragTarget<ItineraryItem>(
        onWillAcceptWithDetails: (details) {
          setState(() => _isDragOver = true);
          return true;
        },
        onLeave: (_) => setState(() => _isDragOver = false),
        onAcceptWithDetails: (details) {
          setState(() {
            _isDragOver = false;
            if (!_dailyPlanItems.any((e) => e.title == details.data.title)) {
              _dailyPlanItems.add(details.data);
            }
          });
          HapticFeedback.lightImpact();
        },
        builder: (ctx, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(_isDragOver ? 12 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: _isDragOver
                  ? Border.all(
                      color: AppColors.neonBlue.withValues(alpha: 0.6),
                      width: 1.5)
                  : null,
              color: _isDragOver
                  ? AppColors.neonBlue.withValues(alpha: 0.05)
                  : Colors.transparent,
            ),
            child: Column(children: [
              if (_isDragOver)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline,
                          color: AppColors.neonBlue, size: 16),
                      const SizedBox(width: 6),
                      Text('Drop to add to Daily Plan',
                          style: GoogleFonts.outfit(
                            color: AppColors.neonBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              TimelineRouteWidget(items: _dailyPlanItems),
            ]),
          );
        },
      ),
    ]);
  }

  // ── Input Bar ───────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
        ),
      ),
      child: GlassInputBar(onSubmitted: _onMessageSubmitted),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat bubble — blue spectrum only
// ---------------------------------------------------------------------------
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  bool get isAI => message.role == MessageRole.ai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAI) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.primaryReversed,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.neonBlue.withValues(alpha: 0.4),
                      blurRadius: 8),
                ],
              ),
              child: const Center(
                child: Text('C',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isAI
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.neonBlue.withValues(alpha: 0.12),
                          AppColors.deepBlue.withValues(alpha: 0.06),
                        ],
                      )
                    : LinearGradient(colors: [
                        AppColors.deepBlue.withValues(alpha: 0.15),
                        AppColors.neonBlue.withValues(alpha: 0.08),
                      ]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isAI ? 4 : 18),
                  bottomRight: Radius.circular(isAI ? 18 : 4),
                ),
                border: Border.all(
                  color: AppColors.neonBlue.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: Text(message.text,
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.5,
                  )),
            ),
          ),
          if (!isAI) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceBorder,
                border: Border.all(
                    color: AppColors.neonBlue.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.neonBlue, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background blobs — single blue blob, no pink
// ---------------------------------------------------------------------------
class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        top: -80,
        right: -60,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonBlue.withValues(alpha: 0.05)),
        ),
      ),
      Positioned(
        top: 350,
        left: -80,
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deepBlue.withValues(alpha: 0.04)),
        ),
      ),
    ]);
  }
}
