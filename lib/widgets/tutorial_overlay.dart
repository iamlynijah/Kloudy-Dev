import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const TutorialOverlay({super.key, required this.onComplete});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  // step 0 = profile setup, steps 1–6 = tab intros
  int _step = 0;
  final _usernameCtrl = TextEditingController();
  Uint8List? _avatarBytes;
  bool _saving = false;
  bool _usernameError = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _tabs = [
    _TabInfo(
      icon: Icons.home_rounded,
      label: 'Home',
      description:
          'Your daily snapshot — calories, spending, sleep, and mood all in one place.',
    ),
    _TabInfo(
      icon: Icons.favorite_rounded,
      label: 'Health',
      description:
          'Log workouts, track gym streaks, and stay on top of your fitness goals.',
    ),
    _TabInfo(
      icon: Icons.restaurant_menu_rounded,
      label: 'Nutrition',
      description:
          'Scan food with AI, log meals, and hit your calorie and macro targets.',
    ),
    _TabInfo(
      icon: Icons.attach_money_rounded,
      label: 'Finances',
      description:
          'Connect your bank to track spending, build savings, and crush debt.',
    ),
    _TabInfo(
      icon: Icons.self_improvement_rounded,
      label: 'Mindset',
      description:
          'Daily check-ins for mood, stress, and sleep. Your mental health matters.',
    ),
    _TabInfo(
      icon: Icons.chat_bubble_rounded,
      label: 'Chat',
      description:
          'Kloudy is your AI wellness coach. Ask anything, anytime.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _submitProfile() async {
    final name = _usernameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _usernameError = true);
      return;
    }
    setState(() { _saving = true; _usernameError = false; });
    // Save username and avatar in parallel
    await Future.wait([
      SupabaseService.saveUsername(name),
      if (_avatarBytes != null)
        SupabaseService.saveAvatarBase64(base64Encode(_avatarBytes!)),
    ]);
    if (!mounted) return;
    setState(() { _saving = false; _step = 1; });
    _animCtrl.forward(from: 0);
  }

  Future<void> _advanceTab() async {
    if (_step < _tabs.length) {
      await _animCtrl.reverse();
      if (!mounted) return;
      setState(() => _step++);
      _animCtrl.forward();
    } else {
      await _animCtrl.reverse();
      await SupabaseService.saveTutorialShown();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _step == 0 ? _buildProfileStep() : _buildTabStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          RichText(
            text: const TextSpan(children: [
              TextSpan(
                  text: 'kloudy',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.5)),
              TextSpan(
                  text: '.',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6C63FF),
                      letterSpacing: -1.5)),
            ]),
          ),
          const SizedBox(height: 14),
          const Text(
            "Let's set up\nyour profile.",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 10),
          Text(
            'Your friends will use this to find and compete with you.',
            style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.4),
          ),
          const Spacer(flex: 1),

          // Avatar picker
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : null,
                    child: _avatarBytes == null
                        ? Icon(Icons.person_rounded,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.3))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C63FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Add a photo',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.35))),
          ),

          const SizedBox(height: 28),

          // Username input
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _usernameError
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text('@',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: TextField(
                    controller: _usernameCtrl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'username',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 17),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 18),
                    ),
                    onChanged: (_) {
                      if (_usernameError) setState(() => _usernameError = false);
                    },
                    onSubmitted: (_) => _submitProfile(),
                  ),
                ),
              ],
            ),
          ),
          if (_usernameError) ...[
            const SizedBox(height: 8),
            Text('Please enter a username to continue.',
                style: TextStyle(
                    color: Colors.redAccent.withValues(alpha: 0.85),
                    fontSize: 13)),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _submitProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Continue',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildTabStep() {
    final tabIndex = _step - 1;
    final tab = _tabs[tabIndex];
    final isLast = _step == _tabs.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(tab.icon, color: const Color(0xFF6C63FF), size: 36),
          ),
          const SizedBox(height: 28),
          Text(tab.label,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text(tab.description,
              style: TextStyle(
                  fontSize: 17,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5)),
          const Spacer(flex: 2),

          // Progress dots
          Row(
            children: List.generate(_tabs.length, (i) {
              final active = i == tabIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 6),
                width: active ? 24 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF6C63FF)
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _advanceTab,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(isLast ? "Let's go" : 'Next',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String label;
  final String description;
  const _TabInfo(
      {required this.icon, required this.label, required this.description});
}
