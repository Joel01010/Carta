import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/sync_service.dart';
import '../services/carta_api_service.dart';
import '../services/supabase_write_service.dart';
import '../core/supabase_connector.dart';
import '../models/chat_response.dart';
import '../widgets/neon_voice_orb.dart';
import '../widgets/itinerary_card.dart';
import '../widgets/timeline_route_widget.dart';
import '../widgets/local_sync_indicator.dart';
import '../widgets/glass_input_bar.dart';
import '../widgets/itinerary_bottom_sheet.dart';

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
// Filter options
// ---------------------------------------------------------------------------
const _filterOptions = ['All', 'Meal 🍽️', 'Event 🎭', 'Drinks 🍹'];
const _filterKeys = ['all', 'meal', 'event', 'drinks'];

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String _activeFilter = 'all';
  bool _isDragOver = false;

  ItineraryModel? _currentItinerary;
  final List<ItineraryItem> _dailyPlanItems = [];

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hey! I'm Carta 👋 Your city, mapped for you. What are we planning?",
      role: MessageRole.ai,
    ),
  ];

  /// userId from Supabase auth — NEVER hardcoded.
  /// The auth gate in main.dart guarantees currentUserId is non-null
  /// before the user reaches this screen.
  String get _userId => currentUserId!;

  @override
  void initState() {
    super.initState();
    SyncService.instance.init();
  }

  // ── Send message to real backend ────────────────────────────────────────
  Future<void> _onMessageSubmitted(String text) async {
    setState(() {
      _messages.add(ChatMessage(text: text, role: MessageRole.user));
      _isLoading = true;
    });

    try {
      final response = await CartaApiService.instance.sendChat(
        userId: _userId,
        message: text,
        previousItinerary: _currentItinerary?.toJson(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(text: response.reply, role: MessageRole.ai));
      });

      // If we got an itinerary, show the bottom sheet
      if (response.itinerary != null) {
        _currentItinerary = response.itinerary;
        _showItinerarySheet(response.itinerary!);
      }
    } on CartaApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          text: "Sorry, I couldn't connect right now. Please try again.",
          role: MessageRole.ai,
        ));
      });
      _showSnackbar(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          text: "Something went wrong. Let's try again!",
          role: MessageRole.ai,
        ));
      });
      _showSnackbar("Carta couldn't connect. Try again.");
    }
  }

  void _showItinerarySheet(ItineraryModel itinerary) {
    ItineraryBottomSheet.show(
      context,
      itinerary: itinerary,
      onSave: () => _saveItinerary(itinerary),
      onRegenerate: _regenerate,
    );
  }

  Future<void> _saveItinerary(ItineraryModel itinerary) async {
    final id = await SupabaseWriteService.instance.saveItinerary(_userId, itinerary);
    if (id != null) {
      _showSnackbar('Plan saved! ✨');
      // Update daily plan items from the itinerary
      setState(() {
        _dailyPlanItems.clear();
        _dailyPlanItems.addAll(itinerary.stops.map((s) => ItineraryItem(
              emoji: s.emoji,
              title: s.name,
              time: s.time,
              location: s.address ?? '',
              isSynced: true,
              category: s.stopType,
            )));
      });
    } else {
      _showSnackbar('Could not save plan');
    }
  }

  void _regenerate() {
    _onMessageSubmitted('Regenerate this plan with different options');
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<ItineraryItem> get _filteredItems {
    if (_currentItinerary == null) return [];
    final items = _currentItinerary!.stops.map((s) => ItineraryItem(
          emoji: s.emoji,
          title: s.name,
          time: s.time,
          location: s.address ?? '',
          isSynced: true,
          category: s.stopType,
        ));
    if (_activeFilter == 'all') return items.toList();
    return items.where((e) => e.category == _activeFilter).toList();
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

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: "Hey! I'm Carta 👋 Your city, mapped for you. What are we planning?",
        role: MessageRole.ai,
      ));
      _currentItinerary = null;
      _dailyPlanItems.clear();
    });
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
                  fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              children: const [
                TextSpan(text: 'Car', style: TextStyle(color: AppColors.neonBlue)),
                TextSpan(text: 'ta', style: TextStyle(color: AppColors.deepBlue)),
              ],
            ),
          ),
          Row(children: [
            if (_messages.length > 1)
              GestureDetector(
                onTap: _clearChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Clear',
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            const LocalSyncIndicator(),
          ]),
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
              fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            "Tell me what you're in the mood for and I'll build your perfect plan.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        NeonVoiceOrb(isListening: _isLoading, onTap: () => HapticFeedback.mediumImpact()),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading
              ? Text('Carta is planning…',
                  key: const ValueKey('loading'),
                  style: GoogleFonts.outfit(
                    color: AppColors.neonBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ))
              : Text('Type below to start',
                  key: const ValueKey('idle'),
                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
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
              width: 3, height: 16,
              decoration: BoxDecoration(
                  color: AppColors.neonBlue, borderRadius: BorderRadius.circular(2))),
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
      if (_isLoading)
        Padding(
          padding: const EdgeInsets.only(left: 56, top: 4),
          child: Row(children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.neonBlue.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Text('Carta is thinking…',
                style: GoogleFonts.outfit(
                    color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
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
                    width: 3, height: 18,
                    decoration: BoxDecoration(
                        color: AppColors.neonBlue, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('Events Hub',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
            if (_currentItinerary != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('₹${_currentItinerary!.totalCostEstimate}',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
                    color: isActive ? AppColors.neonBlue : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.3), blurRadius: 8)]
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

      // Horizontal event cards (from itinerary or empty)
      SizedBox(
        height: 220,
        child: _filteredItems.isEmpty
            ? Center(
                child: Text(
                  _currentItinerary == null
                      ? 'Ask Carta to plan your weekend ✨'
                      : 'No stops in this category',
                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                ))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 8),
                itemCount: _filteredItems.length,
                itemBuilder: (ctx, i) => ItineraryCard(item: _filteredItems[i]),
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
              width: 3, height: 18,
              decoration: BoxDecoration(
                  color: AppColors.deepBlue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('Daily Plan',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
                _dailyPlanItems.isEmpty ? '— save a plan to see it here' : '— drag events here',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11)),
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
                  ? Border.all(color: AppColors.neonBlue.withValues(alpha: 0.6), width: 1.5)
                  : null,
              color: _isDragOver ? AppColors.neonBlue.withValues(alpha: 0.05) : Colors.transparent,
            ),
            child: Column(children: [
              if (_isDragOver)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_circle_outline, color: AppColors.neonBlue, size: 16),
                    const SizedBox(width: 6),
                    Text('Drop to add to Daily Plan',
                        style: GoogleFonts.outfit(
                          color: AppColors.neonBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (_dailyPlanItems.isNotEmpty)
                TimelineRouteWidget(items: _dailyPlanItems)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No stops yet',
                        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ),
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
      child: GlassInputBar(onSubmitted: _isLoading ? null : _onMessageSubmitted),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat bubble
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
        mainAxisAlignment: isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAI) ...[
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.primaryReversed,
                boxShadow: [
                  BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
              child: const Center(
                child: Text('C',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
                border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.20), width: 1),
              ),
              child: Text(message.text,
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary, fontSize: 13.5, height: 1.5)),
            ),
          ),
          if (!isAI) ...[
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceBorder,
                border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.neonBlue, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background blobs
// ---------------------------------------------------------------------------
class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        top: -80, right: -60,
        child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.neonBlue.withValues(alpha: 0.05)),
        ),
      ),
      Positioned(
        top: 350, left: -80,
        child: Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.deepBlue.withValues(alpha: 0.04)),
        ),
      ),
    ]);
  }
}
