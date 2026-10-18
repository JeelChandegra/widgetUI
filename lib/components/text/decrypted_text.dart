library decrypted_text;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';


/// Order in which characters get revealed (sequential mode).
enum RevealDirection { start, end, center }

/// What triggers the animation.
enum AnimateOn {
  /// Mouse enter (desktop/web). Tap also triggers on touch devices.
  hover,

  /// Once, when widget becomes visible.
  view,

  /// Text starts scrambled. Tap to decrypt.
  click,

  /// Once on first view, and again on hover.
  inViewHover,
}

/// Behaviour of taps when [AnimateOn.click] is used.
enum ClickMode {
  /// Decrypt once, further taps ignored.
  once,

  /// Tap toggles between decrypted and encrypted.
  toggle,
}

enum _Dir { forward, reverse }

/// Text that scrambles and reveals itself like a decryption animation.
class DecryptedText extends StatefulWidget {
  const DecryptedText({
    super.key,
    required this.text,
    this.speed = const Duration(milliseconds: 50),
    this.maxIterations = 10,
    this.sequential = false,
    this.revealDirection = RevealDirection.start,
    this.useOriginalCharsOnly = false,
    this.characters =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#\$%^&*()_+',
    this.style,
    this.encryptedStyle,
    this.textAlign,
    this.animateOn = AnimateOn.hover,
    this.clickMode = ClickMode.once,
    this.onComplete,
  });

  /// Final text to show.
  final String text;

  /// Tick interval of the animation.
  final Duration speed;

  /// Number of scramble frames in non-sequential mode.
  final int maxIterations;

  /// Reveal one char per tick instead of scrambling everything.
  final bool sequential;

  /// Reveal order when [sequential] is true.
  final RevealDirection revealDirection;

  /// Scramble using only chars found in [text].
  final bool useOriginalCharsOnly;

  /// Scramble charset (ignored if [useOriginalCharsOnly]).
  final String characters;

  /// Style of revealed chars (and base style).
  final TextStyle? style;

  /// Style merged on top of [style] for still-scrambled chars.
  final TextStyle? encryptedStyle;

  final TextAlign? textAlign;
  final AnimateOn animateOn;
  final ClickMode clickMode;

  /// Called when forward decrypt finishes.
  final VoidCallback? onComplete;

  @override
  State<DecryptedText> createState() => _DecryptedTextState();
}

class _DecryptedTextState extends State<DecryptedText> {
  final _rng = Random();
  final _visKey = UniqueKey();

  late List<String> _chars;
  late String _display;
  Set<int> _revealed = {};
  List<int> _order = [];
  int _pointer = 0;
  int _iteration = 0;
  bool _animating = false;
  bool _hasAnimated = false;
  late bool _decrypted;
  _Dir _dir = _Dir.forward;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant DecryptedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.animateOn != widget.animateOn) {
      _timer?.cancel();
      _animating = false;
      _setup();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setup() {
    _chars = widget.text.runes.map(String.fromCharCode).toList();
    _revealed = {};
    _dir = _Dir.forward;
    if (widget.animateOn == AnimateOn.click) {
      _display = _shuffle({});
      _decrypted = false;
    } else {
      _display = widget.text;
      _decrypted = true;
    }
  }

  List<String> get _available => widget.useOriginalCharsOnly
      ? _chars.toSet().where((c) => c != ' ').toList()
      : widget.characters.runes.map(String.fromCharCode).toList();

  String _shuffle(Set<int> revealed) {
    final pool = _available;
    if (pool.isEmpty) return widget.text;
    final sb = StringBuffer();
    for (var i = 0; i < _chars.length; i++) {
      final c = _chars[i];
      if (c == ' ') {
        sb.write(' ');
      } else if (revealed.contains(i)) {
        sb.write(c);
      } else {
        sb.write(pool[_rng.nextInt(pool.length)]);
      }
    }
    return sb.toString();
  }

  List<int> _computeOrder(int len) {
    if (len <= 0) return [];
    switch (widget.revealDirection) {
      case RevealDirection.start:
        return List.generate(len, (i) => i);
      case RevealDirection.end:
        return List.generate(len, (i) => len - 1 - i);
      case RevealDirection.center:
        final order = <int>[];
        final middle = len ~/ 2;
        var offset = 0;
        while (order.length < len) {
          final idx = offset.isEven
              ? middle + offset ~/ 2
              : middle - ((offset + 1) ~/ 2);
          if (idx >= 0 && idx < len) order.add(idx);
          offset++;
        }
        return order;
    }
  }

  int _nextIndex(Set<int> revealed) {
    final len = _chars.length;
    switch (widget.revealDirection) {
      case RevealDirection.start:
        return revealed.length;
      case RevealDirection.end:
        return len - 1 - revealed.length;
      case RevealDirection.center:
        final middle = len ~/ 2;
        final offset = revealed.length ~/ 2;
        final next =
        revealed.length.isEven ? middle + offset : middle - offset - 1;
        if (next >= 0 && next < len && !revealed.contains(next)) return next;
        for (var i = 0; i < len; i++) {
          if (!revealed.contains(i)) return i;
        }
        return 0;
    }
  }

  Set<int> _all() => {for (var i = 0; i < _chars.length; i++) i};

  // ---- triggers ----

  void _start() {
    _timer?.cancel();
    _iteration = 0;
    _animating = true;
    _timer = Timer.periodic(widget.speed, (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _animating = false;
  }

  void _triggerDecrypt() {
    if (widget.sequential) {
      _order = _computeOrder(_chars.length);
      _pointer = 0;
    }
    setState(() {
      _revealed = {};
      _dir = _Dir.forward;
      _start();
    });
  }

  void _triggerReverse() {
    setState(() {
      if (widget.sequential) {
        _order = _computeOrder(_chars.length).reversed.toList();
        _pointer = 0;
      }
      _revealed = _all();
      _display = _shuffle(_revealed);
      _dir = _Dir.reverse;
      _start();
    });
  }

  void _triggerHover() {
    if (_animating) return;
    setState(() {
      _revealed = {};
      _decrypted = false;
      _display = widget.text;
      _dir = _Dir.forward;
      _start();
    });
  }

  void _resetPlain() {
    setState(() {
      _stop();
      _revealed = {};
      _display = widget.text;
      _decrypted = true;
      _dir = _Dir.forward;
    });
  }

  void _onTap() {
    switch (widget.animateOn) {
      case AnimateOn.click:
        if (widget.clickMode == ClickMode.once) {
          if (_decrypted) return;
          _triggerDecrypt();
        } else {
          _decrypted ? _triggerReverse() : _triggerDecrypt();
        }
        break;
      case AnimateOn.hover:
      case AnimateOn.inViewHover:
        _triggerHover(); // touch fallback
        break;
      case AnimateOn.view:
        break;
    }
  }

  // ---- animation tick ----

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (widget.sequential) {
        if (_dir == _Dir.forward) {
          if (_revealed.length < _chars.length) {
            final next = _nextIndex(_revealed);
            _revealed = {..._revealed, next};
            _display = _shuffle(_revealed);
          } else {
            _stop();
            _decrypted = true;
            widget.onComplete?.call();
          }
        } else {
          if (_pointer < _order.length) {
            final rm = _order[_pointer++];
            _revealed = {..._revealed}..remove(rm);
            _display = _shuffle(_revealed);
            if (_revealed.isEmpty) {
              _stop();
              _decrypted = false;
            }
          } else {
            _stop();
            _decrypted = false;
          }
        }
      } else {
        if (_dir == _Dir.forward) {
          _display = _shuffle(_revealed);
          _iteration++;
          if (_iteration >= widget.maxIterations) {
            _stop();
            _display = widget.text;
            _decrypted = true;
            widget.onComplete?.call();
          }
        } else {
          var cur = _revealed.isEmpty ? _all() : _revealed;
          final removeCount =
          max(1, (_chars.length / max(1, widget.maxIterations)).ceil());
          final list = cur.toList();
          for (var i = 0; i < removeCount && list.isNotEmpty; i++) {
            list.removeAt(_rng.nextInt(list.length));
          }
          final next = list.toSet();
          _display = _shuffle(next);
          _iteration++;
          if (next.isEmpty || _iteration >= widget.maxIterations) {
            _stop();
            _decrypted = false;
            _revealed = {};
            _display = _shuffle({});
          } else {
            _revealed = next;
          }
        }
      }
    });
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final shown = _display.runes.map(String.fromCharCode).toList();
    final done = !_animating && _decrypted;

    Widget child = Center(
      child: Semantics(
        label: widget.text,
        excludeSemantics: true,
        child: Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < shown.length; i++)
                TextSpan(
                  text: shown[i],
                  style: (_revealed.contains(i) || done)
                      ? null
                      : widget.encryptedStyle,
                ),
            ],
          ),
          style: widget.style,
          textAlign: widget.textAlign,
        ),
      ),
    );

    final hoverable = widget.animateOn == AnimateOn.hover ||
        widget.animateOn == AnimateOn.inViewHover;

    if (hoverable) {
      child = MouseRegion(
        onEnter: (_) => _triggerHover(),
        onExit: (_) => _resetPlain(),
        child: child,
      );
    }

    if (widget.animateOn != AnimateOn.view) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: child,
      );
    }

    if (widget.animateOn == AnimateOn.view ||
        widget.animateOn == AnimateOn.inViewHover) {
      child = VisibilityDetector(
        key: _visKey,
        onVisibilityChanged: (info) {
          if (info.visibleFraction >= 0.1 && !_hasAnimated && mounted) {
            _hasAnimated = true;
            _triggerDecrypt();
          }
        },
        child: child,
      );
    }

    return child;
  }
}