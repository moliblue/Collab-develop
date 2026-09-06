import 'package:flutter/material.dart' as material;

import '../../features/collaborative_planner/services/google_translate_service.dart';
import 'app_localization.dart';

/// Drop-in Text widget that routes every static UI string through the active
/// app locale. Dynamic place names and user content remain unchanged unless a
/// matching translation exists in the catalogue.
class Text extends material.StatefulWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.State<Text> createState() => _LocalizedTextState();
}

class _LocalizedTextState extends material.State<Text> {
  static final GoogleTranslateService _translator = GoogleTranslateService();
  static final Map<String, String> _cache = <String, String>{};
  String? _translated;
  String? _requestKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _translateIfNeeded();
  }

  @override
  void didUpdateWidget(covariant Text oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _translateIfNeeded();
  }

  void _translateIfNeeded() {
    final source = widget.data;
    final language = material.Localizations.localeOf(context).languageCode;
    final fallback = source == null ? null : context.tr(source);
    if (source == null || language == 'en' || source.trim().isEmpty) {
      _translated = fallback;
      return;
    }
    final key = '$language\u0000$source';
    _requestKey = key;
    _translated = _cache[key] ?? fallback;
    if (_cache.containsKey(key) || !_translator.isConfigured) return;
    _translator
        .translate(source, target: language)
        .then((value) {
          _cache[key] = value;
          if (mounted && _requestKey == key) {
            setState(() => _translated = value);
          }
        })
        .catchError((_) {
          // Keep the built-in translation or source text when the API is offline.
        });
  }

  @override
  material.Widget build(material.BuildContext context) {
    if (widget.textSpan != null) {
      return material.Text.rich(
        widget.textSpan!,
        style: widget.style,
        strutStyle: widget.strutStyle,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        locale: widget.locale,
        softWrap: widget.softWrap,
        overflow: widget.overflow,
        textScaler: widget.textScaler,
        maxLines: widget.maxLines,
        semanticsLabel: widget.semanticsLabel,
        textWidthBasis: widget.textWidthBasis,
        textHeightBehavior: widget.textHeightBehavior,
        selectionColor: widget.selectionColor,
      );
    }
    return material.Text(
      _translated ?? context.tr(widget.data!),
      style: widget.style,
      strutStyle: widget.strutStyle,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      locale: widget.locale,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      textScaler: widget.textScaler,
      maxLines: widget.maxLines,
      semanticsLabel: widget.semanticsLabel,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      selectionColor: widget.selectionColor,
    );
  }
}
