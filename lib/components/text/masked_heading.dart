library masked_heading;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Reveal animation style.
enum MaskedReveal { rise, wipe, fade, none }

/// When the reveal plays.
enum MaskedTrigger {
  /// Once, when scrolled into view.
  view,

  /// Text visible at rest. Replays on mouse enter.
  hover,

  /// Immediately after first frame.
  mount,
}

/// Heading text that acts as a window onto an image / video.
///
/// Pass any widget as [media] (e.g. `Image`, `VideoPlayer`), or use
/// [MaskedHeading.image].
class MaskedHeading extends StatefulWidget {
  const MaskedHeading({
    super.key,
    required this.text,
    required this.media,
    this.fillScale = 1.25,
    this.parallax = 26,
    this.drift = 18,
    this.brightness = 1,
    this.saturation = 1,
    this.grayscale = false,
    this.reveal = MaskedReveal.rise,
    this.duration = const Duration(milliseconds: 1100),
    this.stagger = const Duration(milliseconds: 90),
    this.trigger = MaskedTrigger.view,
    this.align = TextAlign.center,
    this.weight = 700,
    this.tracking = -0.03,
    this.lineHeight = 1.06,
    this.textScale = 0.115,
    this.style,
  });

  /// Convenience: fill text with an [ImageProvider]
  /// (`NetworkImage`, `AssetImage`, ...).
  MaskedHeading.image({
    super.key,
    required this.text,
    required ImageProvider image,
    this.fillScale = 1.25,
    this.parallax = 26,
    this.drift = 18,
    this.brightness = 1,
    this.saturation = 1,
    this.grayscale = false,
    this.reveal = MaskedReveal.rise,
    this.duration = const Duration(milliseconds: 1100),
    this.stagger = const Duration(milliseconds: 90),
    this.trigger = MaskedTrigger.view,
    this.align = TextAlign.center,
    this.weight = 700,
    this.tracking = -0.03,
    this.lineHeight = 1.06,
    this.textScale = 0.115,
    this.style,
  }) : media = Image(image: image, fit: BoxFit.cover, gaplessPlayback: true);

  final String text;

  /// Widget shown through the letters. Sized to cover the heading box.
  final Widget media;

  /// Media zoom. >1 gives room for parallax/drift.
  final double fillScale;

  /// Max pointer parallax shift in px. 0 disables.
  final double parallax;

  /// Ambient drift amplitude in px. 0 disables.
  final double drift;

  final double brightness;
  final double saturation;
  final bool grayscale;

  final MaskedReveal reveal;
  final Duration duration;

  /// Delay between words (rise only).
  final Duration stagger;
  final MaskedTrigger trigger;
  final TextAlign align;

  /// 100–900.
  final int weight;

  /// Letter spacing in em.
  final double tracking;
  final double lineHeight;

  /// Font size as fraction of widget width (clamped 20–200 px).
  final double textScale;

  /// Base style (fontFamily etc). Size/weight/spacing overridden by props above.
  final TextStyle? style;

  @override
  State<MaskedHeading> createState() => _MaskedHeadingState();
}

class _Layout {
  _Layout(this.whole, this.words, this.positions, this.size, this.fontSize);
  final TextPainter whole;
  final List<TextPainter> words;
  final List<Offset> positions;
  final Size size;
  final double fontSize;
}

class _MaskedHeadingState extends State<MaskedHeading>
    with TickerProviderStateMixin {
  late final AnimationController _reveal;
  late final Ticker _ticker;
  final _offset = ValueNotifier<Offset>(Offset.zero);
  final _visKey = UniqueKey();

  Offset _target = Offset.zero;
  Offset _cur = Offset.zero;
  double _clock = 0;
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  bool _played = false;
  bool _reduce = false;
  bool _configured = false;

  ui.Image? _cache;
  Object? _cacheKey;
  ui.Image? _frame;

  List<String> get _words =>
      widget.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  bool get _settledMode => widget.reveal == MaskedReveal.none || _reduce;

  double get _durS => widget.duration.inMicroseconds / 1e6;
  double get _staggerS => widget.stagger.inMicroseconds / 1e6;

  double get _totalS {
    if (widget.reveal == MaskedReveal.rise) {
      return _durS + _staggerS * max(0, _words.length - 1);
    }
    return _durS;
  }

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_configured || reduce != _reduce) {
      _reduce = reduce;
      _configure();
    }
  }

  @override
  void didUpdateWidget(covariant MaskedHeading old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.reveal != widget.reveal ||
        old.trigger != widget.trigger ||
        old.duration != widget.duration ||
        old.stagger != widget.stagger) {
      _configure();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _reveal.dispose();
    _offset.dispose();
    _cache?.dispose();
    _frame?.dispose();
    super.dispose();
  }

  void _configure() {
    _configured = true;
    _reveal.stop();
    _reveal.duration =
        Duration(microseconds: max(1, (_totalS * 1e6).round()));
    _played = false;
    if (_settledMode || widget.trigger == MaskedTrigger.hover) {
      _reveal.value = 1;
    } else {
      _reveal.value = 0;
      if (widget.trigger == MaskedTrigger.mount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _play();
        });
      }
    }
  }

  void _play() {
    if (_settledMode) return;
    _played = true;
    _reveal.forward(from: 0);
  }

  // ---- drift + parallax ----

  void _onTick(Duration elapsed) {
    final dt = min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _clock += dt;
    final dx = sin(_clock * 0.21) * widget.drift;
    final dy = cos(_clock * 0.17) * widget.drift * 0.6;
    final ease = 1 - exp(-dt / 0.18);
    _cur += (_target + Offset(dx, dy) - _cur) * ease;
    _offset.value = _cur;
  }

  void _pointer(Offset local) {
    if (widget.parallax <= 0 || _size.isEmpty) return;
    final nx = (local.dx / (_size.width == 0 ? 1 : _size.width)) * 2 - 1;
    final ny = (local.dy / (_size.height == 0 ? 1 : _size.height)) * 2 - 1;
    _target = Offset(
      nx.clamp(-1.0, 1.0) * -widget.parallax,
      ny.clamp(-1.0, 1.0) * -widget.parallax,
    );
  }

  // ---- layout + mask ----

  _Layout _layout(double w, TextDirection dir) {
    final fs = (w * widget.textScale).clamp(20.0, 200.0).toDouble();
    final w100 = (widget.weight.clamp(100, 900) / 100).round() - 1;
    final style = (widget.style ?? const TextStyle()).copyWith(
      color: Colors.white,
      fontSize: fs,
      fontWeight: FontWeight.values[w100],
      letterSpacing: widget.tracking * fs,
      height: widget.lineHeight,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final words = _words;
    final joined = words.join(' ');

    final whole = TextPainter(
      text: TextSpan(text: joined, style: style),
      textAlign: widget.align,
      textDirection: dir,
    )..layout(minWidth: w, maxWidth: w);

    final painters = <TextPainter>[];
    final pos = <Offset>[];
    var idx = 0;
    for (final word in words) {
      final boxes = whole.getBoxesForSelection(
        TextSelection(baseOffset: idx, extentOffset: idx + word.length),
      );
      pos.add(boxes.isEmpty
          ? Offset.zero
          : Offset(boxes.first.left, boxes.first.top));
      painters.add(TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: dir,
      )..layout());
      idx += word.length + 1;
    }
    return _Layout(whole, painters, pos, Size(w, whole.height), fs);
  }

  ui.Image _render(_Layout l, double dpr, {double? time}) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(dpr);
    if (time == null) {
      l.whole.paint(c, Offset.zero);
    } else {
      final rise = l.fontSize * 1.15;
      for (var i = 0; i < l.words.length; i++) {
        final p = ((time - i * _staggerS) / max(1e-6, _durS)).clamp(0.0, 1.0);
        final e = Curves.easeOutQuart.transform(p);
        l.words[i].paint(c, l.positions[i] + Offset(0, rise * (1 - e)));
      }
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync(
      max(1, (l.size.width * dpr).ceil()),
      max(1, (l.size.height * dpr).ceil()),
    );
    pic.dispose();
    return img;
  }

  void _retire(ui.Image? img) {
    if (img == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => img.dispose());
  }

  ui.Image _maskFor(_Layout l, double dpr, Object key) {
    final animatingRise = widget.reveal == MaskedReveal.rise &&
        !_settledMode &&
        _reveal.value < 1;
    if (animatingRise) {
      final img = _render(l, dpr, time: _reveal.value * _totalS);
      _retire(_frame);
      _frame = img;
      return img;
    }
    if (_frame != null) {
      _retire(_frame);
      _frame = null;
    }
    if (_cacheKey != key || _cache == null) {
      _retire(_cache);
      _cache = _render(l, dpr);
      _cacheKey = key;
    }
    return _cache!;
  }

  ColorFilter? _filter() {
    final b = widget.brightness;
    final s = widget.grayscale ? 0.0 : widget.saturation;
    if (b == 1 && s == 1) return null;
    return ColorFilter.matrix(<double>[
      (0.213 + 0.787 * s) * b, (0.715 - 0.715 * s) * b, (0.072 - 0.072 * s) * b, 0, 0,
      (0.213 - 0.213 * s) * b, (0.715 + 0.285 * s) * b, (0.072 - 0.072 * s) * b, 0, 0,
      (0.213 - 0.213 * s) * b, (0.715 - 0.715 * s) * b, (0.072 + 0.928 * s) * b, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  Widget _mediaLayer() {
    final filter = _filter();
    return ValueListenableBuilder<Offset>(
      valueListenable: _offset,
      child: SizedBox.expand(child: widget.media),
      builder: (_, off, child) {
        final maxX = max(0.0, (widget.fillScale - 1) / 2 * _size.width);
        final maxY = max(0.0, (widget.fillScale - 1) / 2 * _size.height);
        Widget m = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(
              off.dx.clamp(-maxX, maxX).toDouble(),
              off.dy.clamp(-maxY, maxY).toDouble(),
            )
            ..scale(widget.fillScale),
          child: child,
        );
        if (filter != null) m = ColorFiltered(colorFilter: filter, child: m);
        return m;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget out = LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite
          ? c.maxWidth
          : MediaQuery.sizeOf(context).width;
      if (_words.isEmpty) return SizedBox(width: w);

      final l = _layout(w, dir);
      _size = l.size;
      final key = Object.hash(w, l.size.height, dpr, widget.text,
          widget.style, widget.align, widget.weight, widget.tracking,
          widget.lineHeight, widget.textScale);

      return MouseRegion(
        onEnter: (_) {
          if (widget.trigger == MaskedTrigger.hover) _play();
        },
        onHover: (e) => _pointer(e.localPosition),
        onExit: (_) => _target = Offset.zero,
        child: Listener(
          onPointerMove: (e) => _pointer(e.localPosition),
          onPointerUp: (_) => _target = Offset.zero,
          onPointerCancel: (_) => _target = Offset.zero,
          child: SizedBox(
            width: w,
            height: l.size.height,
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) {
                final img = _maskFor(l, dpr, key);
                Widget masked = ShaderMask(
                  blendMode: BlendMode.dstIn,
                  // Shader coords are in parent space, not child space.
                  // Must shift by rect origin or mask lands off-target.
                  shaderCallback: (rect) => ui.ImageShader(
                    img,
                    TileMode.decal,
                    TileMode.decal,
                    (Matrix4.identity()
                      ..translate(rect.left, rect.top)
                      ..scale(1 / dpr, 1 / dpr, 1))
                        .storage,
                  ),
                  child: _mediaLayer(),
                );
                switch (widget.reveal) {
                  case MaskedReveal.wipe:
                    final p = Curves.easeInOutCubic.transform(_reveal.value);
                    return ClipRect(clipper: _WipeClipper(p), child: masked);
                  case MaskedReveal.fade:
                    final p = Curves.easeOutCubic.transform(_reveal.value);
                    return Opacity(
                      opacity: p,
                      child: Transform.scale(scale: 1.08 - 0.08 * p, child: masked),
                    );
                  case MaskedReveal.rise:
                  case MaskedReveal.none:
                    return masked;
                }
              },
            ),
          ),
        ),
      );
    });

    if (widget.trigger == MaskedTrigger.view) {
      out = VisibilityDetector(
        key: _visKey,
        onVisibilityChanged: (info) {
          if (info.visibleFraction >= 0.25 && !_played && mounted) _play();
        },
        child: out,
      );
    }

    return Semantics(
      header: true,
      label: widget.text,
      excludeSemantics: true,
      child: out,
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  _WipeClipper(this.p);
  final double p;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * p, size.height);

  @override
  bool shouldReclip(covariant _WipeClipper old) => old.p != p;
}