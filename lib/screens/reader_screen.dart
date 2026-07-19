import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../services/reading_progress.dart';
import '../widgets/orp_word.dart';
import '../widgets/vertical_speed_control.dart';
import '../widgets/word_scrubber.dart';

// Sane technical floor/ceiling so the tick timer always has a valid,
// reasonable duration. Not shown anywhere in the UI as a limit.
const _minWpm = 20;
const _maxWpm = 3000;
const _defaultWpm = 300;
const _wpmPrefKey = 'reading_speed_wpm';
const _orpFixedPrefKey = 'orp_fixed_mode';

const _speedDragSensitivity = 3.0; // wpm change per pixel dragged
const _pixelsPerScrubWord = 24.0; // drag distance to step one word

const _topBarHeight = 56.0;
const _bottomBarHeight = 96.0;
const _speedBarWidth = 64.0;
const _uiHideDelay = Duration(seconds: 4);

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<String>? _words;
  int _index = 0;
  bool _isPlaying = false;
  int _wpm = _defaultWpm;
  bool _orpFixed = false;
  Timer? _timer;

  bool _uiVisible = false;
  Timer? _hideTimer;

  double _scrubAccumulator = 0;

  String get _bookId => widget.book.id;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWpm = prefs.getInt(_wpmPrefKey);
    final savedOrpFixed = prefs.getBool(_orpFixedPrefKey);
    final savedIndex = await ReadingProgressStore.load(_bookId);
    final words = await widget.book.loadWords();
    if (!mounted) return;
    setState(() {
      _words = words;
      if (savedWpm != null) _wpm = savedWpm.clamp(_minWpm, _maxWpm);
      if (savedOrpFixed != null) _orpFixed = savedOrpFixed;
      _index = words.isEmpty ? 0 : savedIndex.clamp(0, words.length - 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideTimer?.cancel();
    _saveProgress();
    super.dispose();
  }

  Duration get _tickDuration =>
      Duration(milliseconds: (60000 / _wpm).round());

  void _togglePlay() {
    if (_words == null || _words!.isEmpty) return;
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      if (_index >= _words!.length - 1) _index = 0;
      _startTimer();
    } else {
      _timer?.cancel();
      _saveProgress();
      _revealUi();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickDuration, (_) {
      var reachedEnd = false;
      setState(() {
        _index++;
        if (_index >= _words!.length) {
          _index = _words!.length - 1;
          _isPlaying = false;
          _timer?.cancel();
          reachedEnd = true;
        } else if (_index % 25 == 0) {
          _saveProgress();
        }
      });
      if (reachedEnd) {
        _saveProgress();
        _revealUi();
      }
    });
  }

  void _saveProgress() {
    if (_words == null) return;
    ReadingProgressStore.save(_bookId, _index);
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _index = 0;
    });
    ReadingProgressStore.clear(_bookId);
    _resetHideTimer();
  }

  void _applyWpm(int wpm, {required bool persist}) {
    setState(() => _wpm = wpm);
    if (_isPlaying) _startTimer();
    if (persist) _persistWpm(wpm);
  }

  Future<void> _persistWpm(int wpm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wpmPrefKey, wpm);
  }

  void _onSpeedDragDelta(double dy) {
    // Dragging up moves dy negative, and should increase speed.
    final next = (_wpm - dy * _speedDragSensitivity).round().clamp(
      _minWpm,
      _maxWpm,
    );
    if (next != _wpm) _applyWpm(next, persist: false);
  }

  void _onScrubDragDelta(double dx) {
    if (_words == null || _words!.isEmpty) return;
    if (_isPlaying) {
      _isPlaying = false;
      _timer?.cancel();
    }

    _scrubAccumulator += dx;
    var step = 0;
    while (_scrubAccumulator >= _pixelsPerScrubWord) {
      step++;
      _scrubAccumulator -= _pixelsPerScrubWord;
    }
    while (_scrubAccumulator <= -_pixelsPerScrubWord) {
      step--;
      _scrubAccumulator += _pixelsPerScrubWord;
    }
    if (step != 0) {
      setState(() {
        _index = (_index + step).clamp(0, _words!.length - 1);
      });
    }
  }

  Future<void> _toggleDisplayMode() async {
    setState(() => _orpFixed = !_orpFixed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orpFixedPrefKey, _orpFixed);
    _resetHideTimer();
  }

  void _revealUi() {
    setState(() => _uiVisible = true);
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_uiHideDelay, () {
      if (mounted) setState(() => _uiVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;

    return Scaffold(
      backgroundColor: Colors.black,
      body: words == null
          ? const Center(child: CircularProgressIndicator())
          : words.isEmpty
          ? const Center(
              child: Text(
                'Questo libro sembra vuoto.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlay,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: OrpWord(
                            word: words[_index],
                            orpFixed: _orpFixed,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _topBarHeight,
                    child: _RevealableZone(
                      visible: _uiVisible,
                      onReveal: _revealUi,
                      controls: _ReaderTopBar(
                        title: widget.book.title,
                        orpFixed: _orpFixed,
                        onBack: () => Navigator.of(context).pop(),
                        onRestart: _restart,
                        onToggleDisplayMode: _toggleDisplayMode,
                      ),
                    ),
                  ),
                  Positioned(
                    top: _topBarHeight,
                    right: 0,
                    bottom: _bottomBarHeight,
                    width: _speedBarWidth,
                    child: _RevealableZone(
                      visible: _uiVisible,
                      onReveal: _revealUi,
                      controls: VerticalSpeedControl(
                        wpm: _wpm,
                        onDragDelta: _onSpeedDragDelta,
                        onInteraction: _resetHideTimer,
                        onDragEnd: () => _persistWpm(_wpm),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _bottomBarHeight,
                    child: _RevealableZone(
                      visible: _uiVisible,
                      onReveal: _revealUi,
                      controls: WordScrubber(
                        progressLabel: '${_index + 1} / ${words.length}',
                        onDragDelta: _onScrubDragDelta,
                        onInteraction: _resetHideTimer,
                        onDragEnd: _saveProgress,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// An area that, while hidden, is an invisible tap target revealing
/// [controls]; while visible, shows and forwards gestures to [controls].
/// Only one of the two is ever hit-testable at a time.
class _RevealableZone extends StatelessWidget {
  final bool visible;
  final VoidCallback onReveal;
  final Widget controls;

  const _RevealableZone({
    required this.visible,
    required this.onReveal,
    required this.controls,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: visible,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReveal,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: controls,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  final String title;
  final bool orpFixed;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final VoidCallback onToggleDisplayMode;

  const _ReaderTopBar({
    required this.title,
    required this.orpFixed,
    required this.onBack,
    required this.onRestart,
    required this.onToggleDisplayMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              orpFixed ? Icons.center_focus_strong : Icons.format_align_center,
              color: Colors.white,
            ),
            tooltip: orpFixed
                ? 'Lettera ORP fissa (tocca per centrare la parola)'
                : 'Parola centrata (tocca per fissare la lettera ORP)',
            onPressed: onToggleDisplayMode,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.white),
            tooltip: "Ricomincia dall'inizio",
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}
