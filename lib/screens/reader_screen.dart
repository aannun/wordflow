import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../services/reading_progress.dart';
import '../widgets/orp_word.dart';
import '../widgets/scrolling_words_view.dart';
import '../widgets/vertical_speed_control.dart';
import '../widgets/word_scrubber.dart';

// Sane technical floor/ceiling so the tick timer always has a valid,
// reasonable duration. Not shown anywhere in the UI as a limit.
const _minWpm = 20;
const _maxWpm = 3000;
const _defaultWpm = 300;
const _wpmPrefKey = 'reading_speed_wpm';
const _displayModePrefKey = 'reader_display_mode';

const _speedDragSensitivity = 3.0; // wpm change per pixel dragged
const _pixelsPerScrubWord = 24.0; // drag distance to step one word

const _topBarHeight = 56.0;
const _bottomBarHeight = 96.0;
const _speedBarWidth = 64.0;
const _uiHideDelay = Duration(seconds: 4);

const _scrollFontSize = 44.0;
const _scrollTextStyle = TextStyle(
  fontSize: _scrollFontSize,
  fontWeight: FontWeight.w400,
  color: Colors.white,
);
const _scrollWindowBack = 6;
const _scrollWindowForward = 24;
const _scrollMinWordMs = 30;
const _scrollMaxWordMs = 5000;

/// How the current word (or words, for [horizontalScroll]) is displayed.
enum ReaderDisplayMode {
  /// The word is centered on screen as a block; no letter is highlighted
  /// since there's no fixed anchor point for it to mean anything.
  wordCentered,

  /// The word's ORP letter is highlighted and pinned to the horizontal
  /// center, with the rest of the word extending left/right of it.
  orpFixed,

  /// Words flow past a fixed marker in a continuous horizontal stream, at
  /// a constant pixel speed, instead of replacing each other in place.
  /// Unlike the other two modes, word dwell time isn't exactly wpm — it's
  /// however long that word's own width takes to cross the marker at a
  /// constant speed, so motion stays smooth instead of speeding up and
  /// slowing down between short and long words.
  horizontalScroll,
}

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with TickerProviderStateMixin {
  List<String>? _words;
  bool _unavailableOffline = false;
  bool _loadError = false;
  int _index = 0;
  bool _isPlaying = false;
  int _wpm = _defaultWpm;
  ReaderDisplayMode _displayMode = ReaderDisplayMode.wordCentered;
  Timer? _timer;

  bool _uiVisible = false;
  Timer? _hideTimer;

  double _scrubAccumulator = 0;

  late final AnimationController _scrollAnim = AnimationController(
    vsync: this,
  )..addStatusListener(_onScrollAnimStatusChanged);
  List<String> _scrollWindowWords = const [];
  int _scrollWindowStart = 0;
  List<double> _scrollWindowWidths = const [];
  double _scrollAvgWordWidth = 120;

  String get _bookId => widget.book.id;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWpm = prefs.getInt(_wpmPrefKey);
    final savedModeIndex = prefs.getInt(_displayModePrefKey);
    final savedIndex = await ReadingProgressStore.load(_bookId);

    final List<String> words;
    try {
      words = await widget.book.loadWords();
    } on BookUnavailableOfflineException {
      if (mounted) setState(() => _unavailableOffline = true);
      return;
    } catch (_) {
      // Covers e.g. a corrupt/encrypted/image-only PDF with no
      // extractable text — extraction can throw in ways specific to the
      // PDF library, so this is deliberately a catch-all rather than a
      // narrower type.
      if (mounted) setState(() => _loadError = true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _words = words;
      if (savedWpm != null) _wpm = savedWpm.clamp(_minWpm, _maxWpm);
      if (savedModeIndex != null &&
          savedModeIndex >= 0 &&
          savedModeIndex < ReaderDisplayMode.values.length) {
        _displayMode = ReaderDisplayMode.values[savedModeIndex];
      }
      _index = words.isEmpty ? 0 : savedIndex.clamp(0, words.length - 1);
      if (_displayMode == ReaderDisplayMode.horizontalScroll) {
        _recomputeScrollWindow(_index);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideTimer?.cancel();
    _scrollAnim.dispose();
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
      _startAdvancing();
    } else {
      _stopAdvancing();
      _saveProgress();
      _revealUi();
    }
  }

  void _startAdvancing() {
    if (_displayMode == ReaderDisplayMode.horizontalScroll) {
      _recomputeScrollWindow(_index);
      _advanceScrollAnim();
    } else {
      _startTimer();
    }
  }

  void _stopAdvancing() {
    _timer?.cancel();
    _scrollAnim.stop();
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

  /// Starts the scroll animation carrying the current word to the next
  /// one, at a constant pixel speed derived from wpm — so its duration
  /// depends on how wide these two words are, not a fixed interval.
  void _advanceScrollAnim() {
    final words = _words;
    if (words == null || _index >= words.length - 1) return;

    final distancePx = _scrollWordCenterDistance();
    final velocity = (_wpm / 60000) * _scrollAvgWordWidth; // px per ms
    final durationMs = velocity > 0 ? distancePx / velocity : 200.0;

    _scrollAnim
      ..duration = Duration(
        milliseconds: durationMs
            .clamp(_scrollMinWordMs, _scrollMaxWordMs)
            .round(),
      )
      ..forward(from: 0);
  }

  void _onScrollAnimStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!_isPlaying || _displayMode != ReaderDisplayMode.horizontalScroll) {
      return;
    }

    final words = _words!;
    setState(() {
      _index++;
      if (_index >= words.length - 1) {
        _isPlaying = false;
      } else if (_index % 25 == 0) {
        _saveProgress();
      }
    });
    _ensureScrollWindowCovers(_index);

    if (_index >= words.length - 1) {
      _saveProgress();
      _revealUi();
    } else {
      _advanceScrollAnim();
    }
  }

  void _saveProgress() {
    if (_words == null) return;
    ReadingProgressStore.save(_bookId, _index);
  }

  void _restart() {
    _stopAdvancing();
    setState(() {
      _isPlaying = false;
      _index = 0;
      if (_displayMode == ReaderDisplayMode.horizontalScroll) {
        _recomputeScrollWindow(0);
        _scrollAnim.value = 0;
      }
    });
    ReadingProgressStore.clear(_bookId);
    _resetHideTimer();
  }

  void _applyWpm(int wpm, {required bool persist}) {
    setState(() => _wpm = wpm);
    if (_isPlaying) {
      if (_displayMode == ReaderDisplayMode.horizontalScroll) {
        _advanceScrollAnim();
      } else {
        _startTimer();
      }
    }
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
      _stopAdvancing();
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
        if (_displayMode == ReaderDisplayMode.horizontalScroll) {
          _recomputeScrollWindow(_index);
          _scrollAnim.value = 0;
        }
      });
    }
  }

  /// Center-to-center pixel distance between the current word and the
  /// next one — half of each word's width plus the space between them.
  double _scrollWordCenterDistance() {
    final widths = _scrollWindowWidths;
    if (widths.isEmpty) return _scrollAvgWordWidth;
    final localCurrent = (_index - _scrollWindowStart).clamp(
      0,
      widths.length - 1,
    );
    final localNext = (localCurrent + 1).clamp(0, widths.length - 1);
    if (localNext == localCurrent) return _scrollAvgWordWidth;
    return widths[localCurrent] / 2 + widths[localNext] / 2;
  }

  /// Recomputes the window only if [index] has drifted close to its
  /// edge — called from the hot auto-advance path, where re-measuring
  /// text every single word would be wasteful.
  void _ensureScrollWindowCovers(int index) {
    final withinExistingWindow =
        _scrollWindowWidths.isNotEmpty &&
        index >= _scrollWindowStart + 2 &&
        index <= _scrollWindowStart + _scrollWindowWidths.length - 4;
    if (!withinExistingWindow) _recomputeScrollWindow(index);
  }

  /// Measures the small slice of words around [index] needed to render
  /// the scrolling strip, and refreshes the average word width used to
  /// derive scroll speed from wpm. Cheap (a couple dozen text layouts),
  /// and deliberately not called on every animation frame.
  void _recomputeScrollWindow(int index) {
    final words = _words;
    if (words == null || words.isEmpty) return;

    final start = (index - _scrollWindowBack).clamp(0, words.length - 1);
    final end = (index + _scrollWindowForward).clamp(0, words.length - 1);

    final painter = TextPainter(textDirection: TextDirection.ltr);
    final widths = <double>[];
    for (var i = start; i <= end; i++) {
      painter.text = TextSpan(text: '${words[i]} ', style: _scrollTextStyle);
      painter.layout();
      widths.add(painter.width);
    }

    _scrollWindowStart = start;
    _scrollWindowWords = words.sublist(start, end + 1);
    _scrollWindowWidths = widths;
    if (widths.isNotEmpty) {
      _scrollAvgWordWidth = widths.reduce((a, b) => a + b) / widths.length;
    }
  }

  Future<void> _cycleDisplayMode() async {
    final modes = ReaderDisplayMode.values;
    final next = modes[(_displayMode.index + 1) % modes.length];
    setState(() {
      _displayMode = next;
      if (next == ReaderDisplayMode.horizontalScroll) {
        _recomputeScrollWindow(_index);
        _scrollAnim.stop();
        _scrollAnim.value = 0;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayModePrefKey, next.index);
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

  Widget _buildWordDisplay(BuildContext context, List<String> words) {
    if (_displayMode == ReaderDisplayMode.horizontalScroll) {
      return ScrollingWordsView(
        windowWords: _scrollWindowWords,
        windowStart: _scrollWindowStart,
        windowWidths: _scrollWindowWidths,
        currentIndex: _index,
        progress: _scrollAnim,
        style: _scrollTextStyle,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: OrpWord(
          word: words[_index],
          orpFixed: _displayMode == ReaderDisplayMode.orpFixed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _unavailableOffline
          ? _ReaderMessage(
              icon: Icons.cloud_off,
              title: '"${widget.book.title}" non è disponibile offline',
              subtitle: 'Aprilo una volta con la connessione attiva: da '
                  'quel momento resterà leggibile anche offline.',
            )
          : _loadError
          ? const _ReaderMessage(
              icon: Icons.error_outline,
              title: 'Non è stato possibile leggere questo file',
              subtitle: 'Il PDF potrebbe essere protetto, danneggiato, o '
                  'contenere solo pagine scansionate senza testo '
                  'selezionabile.',
            )
          : words == null
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
                      child: _buildWordDisplay(context, words),
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
                        mode: _displayMode,
                        onBack: () => Navigator.of(context).pop(),
                        onRestart: _restart,
                        onCycleDisplayMode: _cycleDisplayMode,
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
  final ReaderDisplayMode mode;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final VoidCallback onCycleDisplayMode;

  const _ReaderTopBar({
    required this.title,
    required this.mode,
    required this.onBack,
    required this.onRestart,
    required this.onCycleDisplayMode,
  });

  IconData get _icon => switch (mode) {
    ReaderDisplayMode.wordCentered => Icons.format_align_center,
    ReaderDisplayMode.orpFixed => Icons.center_focus_strong,
    ReaderDisplayMode.horizontalScroll => Icons.trending_flat,
  };

  String get _tooltip => switch (mode) {
    ReaderDisplayMode.wordCentered =>
      'Parola centrata (tocca per fissare la lettera ORP)',
    ReaderDisplayMode.orpFixed =>
      'Lettera ORP fissa (tocca per scorrimento orizzontale)',
    ReaderDisplayMode.horizontalScroll =>
      'Scorrimento orizzontale (tocca per parola centrata)',
  };

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
            icon: Icon(_icon, color: Colors.white),
            tooltip: _tooltip,
            onPressed: onCycleDisplayMode,
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

/// A full-screen message shown instead of the reader when the book can't
/// be displayed (offline and not cached yet, or a load/parse failure).
class _ReaderMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ReaderMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              label: const Text(
                'Torna alla libreria',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
