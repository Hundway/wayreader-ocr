import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OcrPage extends StatefulWidget {
  final String imagePath;

  const OcrPage({super.key, required this.imagePath});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  // External services
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _tts = FlutterTts();

  // UI / state
  bool _loading = true;
  bool _translating = false;
  bool _showTranslation = false;
  bool _isSpeaking = false;

  double _imageRatio = 0.4;

  String _sourceText = "Processing OCR...";
  String _translatedText = "";

  // language maps: code -> display name, and code -> TTS locale
  final Map<String, String> _languageNames = const {
    'en': 'English (US)',
    'pt': 'Português (Brasil)',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
  };

  final Map<String, String> _localeMap = const {
    'en': 'en-US',
    'pt': 'pt-BR',
    'es': 'es-ES',
    'fr': 'fr-FR',
    'de': 'de-DE',
  };

  String _targetLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _initTts();
    _performOcr();
  }

  void _initTts() {
    // sensible defaults
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);

    // handlers to keep UI state in sync
    _tts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });

    _tts.setCancelHandler(() {
      setState(() => _isSpeaking = false);
    });

    _tts.setErrorHandler((msg) {
      setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // -------------------------
  // Your exact clean OCR functions
  // -------------------------
  String normalizeChars(String t) {
    t = t.replaceAll(RegExp(r'[\u0000-\u001F\u007F\uFFFD]'), '');
    t = t
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('•', '-')
        .replaceAll('·', '-')
        .replaceAll('¬', '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool isGarbage(String l) =>
      l.length <= 1 || RegExp(r'^[.,\-–—:;!?]+$').hasMatch(l);

  bool isTerminalHard(String l) {
    final t = l.trim();
    if (t.isEmpty) return false;

    String last = t.characters.last;
    if (last == '"' || last == "'") {
      if (t.length < 2) return false;
      last = t.characters.elementAt(t.length - 2);
    }
    return '.!?'.contains(last);
  }

  bool isSoftBreak(String l) => RegExp(r'[:,;]$').hasMatch(l.trim());

  bool startsWithCapital(String s) =>
      s.isNotEmpty && RegExp(r'[A-ZÁÉÍÓÚÀÈÌÒÙ]').hasMatch(s[0]);

  String cleanOcrText(String raw) {
    final lines = raw
        .split('\n')
        .map(normalizeChars)
        .where((l) => l.isNotEmpty && !isGarbage(l))
        .toList();

    if (lines.isEmpty) return "";

    final out = <String>[];
    var current = lines.first.trim();

    for (int i = 1; i < lines.length; i++) {
      final p = current.trim();
      final n = lines[i].trim();

      // 1. Hyphen breaks
      if (p.endsWith('-') && n.isNotEmpty && n[0].toLowerCase() == n[0]) {
        current = p.substring(0, p.length - 1) + n;
        continue;
      }

      // 2. Letter-to-letter merge
      if (RegExp(r'[a-zA-Z]$').hasMatch(p) &&
          RegExp(r'^[a-zA-Z]').hasMatch(n)) {
        current = "$p $n";
        continue;
      }

      // 3. Hard punctuation → paragraph break
      if (isTerminalHard(p)) {
        out.add(p);
        current = n;
        continue;
      }

      // 4. Soft punctuation → merge
      if (isSoftBreak(p)) {
        current = "$p $n";
        continue;
      }

      // 5. Next begins lowercase → merge
      if (!startsWithCapital(n)) {
        current = "$p $n";
        continue;
      }

      // 6. Very short previous line → merge
      if (p.length < 5) {
        current = "$p $n";
        continue;
      }

      // Default: new paragraph
      out.add(p);
      current = n;
    }

    out.add(current.trim());

    // Add indent
    return out.map((p) => p).join("\n\n");
  }

  // -------------------------
  // OCR
  // -------------------------
  Future<void> _performOcr() async {
    setState(() {
      _loading = true;
      _sourceText = "Processing OCR...";
      _translatedText = "";
      _showTranslation = false;
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(widget.imagePath),
      );

      final raw = result.text.trim();
      final cleaned = raw.isEmpty ? "No text recognized." : cleanOcrText(raw);

      setState(() {
        _sourceText = cleaned;
      });
    } catch (e) {
      setState(() {
        _sourceText = "OCR failed: $e";
      });
    } finally {
      recognizer.close();
      setState(() {
        _loading = false;
      });
    }
  }

  // -------------------------
  // Translation toggle
  // -------------------------
  Future<void> _toggleTranslation() async {
    if (_translating || _loading) return;

    // If showing translated, switch back to original
    if (_showTranslation) {
      setState(() {
        _showTranslation = false;
      });
      return;
    }

    // If we already have a translation cached, show it
    if (_translatedText.isNotEmpty) {
      setState(() {
        _showTranslation = true;
      });
      return;
    }

    // translate the cleaned source text
    setState(() {
      _translating = true;
    });

    try {
      final result = await _translator.translate(
        _sourceText,
        to: _targetLanguage,
      );

      // translator returns plain text; keep it as-is
      setState(() {
        _translatedText = result.text;
        _showTranslation = true;
      });
    } catch (e) {
      setState(() {
        _translatedText = "Translation failed: $e";
        _showTranslation = true;
      });
    } finally {
      setState(() {
        _translating = false;
      });
    }
  }

  // -------------------------
  // TTS: configure voice for selected language
  // -------------------------
  Future<void> _configureTtsLanguage() async {
    final locale = _localeMap[_targetLanguage] ?? 'en-US';
    try {
      await _tts.setLanguage(locale);

      // Try to pick a voice matching the language (if voices available)
      final voices = await _tts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        // voices are usually maps with 'name' and 'locale'
        final match = voices.firstWhere((v) {
          final vLocale = (v is Map && v.containsKey('locale'))
              ? v['locale']
              : (v is String ? v : '');
          if (vLocale == null) return false;
          return vLocale.toString().toLowerCase().startsWith(
            locale.split('-').first,
          );
        }, orElse: () => null);
        if (match != null) {
          try {
            await _tts.setVoice(match);
          } catch (_) {
            // ignore if cannot set voice
          }
        }
      }
    } catch (e) {
      debugPrint('TTS configure failed: $e');
    }
  }

  // Toggle read aloud: start if not speaking, stop if speaking
  Future<void> _toggleReadAloud() async {
    final textToRead = _showTranslation && _translatedText.isNotEmpty
        ? _translatedText
        : _sourceText;

    if (_isSpeaking) {
      await _tts.stop(); // completion/cancel handler will update state
      return;
    }

    // prepare tts language/voice
    await _configureTtsLanguage();

    try {
      // speak text; handlers will set _isSpeaking = true/false
      await _tts.speak(textToRead);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = _showTranslation && _translatedText.isNotEmpty
        ? _translatedText
        : _sourceText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR & Translate'),
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        elevation: 2,
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          final imageHeight = maxH * _imageRatio;
          final textAreaHeight = maxH - imageHeight;

          return Column(
            children: [
              // image area
              SizedBox(
                height: imageHeight,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),

              // draggable divider
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _imageRatio += details.delta.dy / maxH;
                    _imageRatio = _imageRatio.clamp(0.1, 0.85);
                  });
                },
                child: Container(
                  height: 24,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.drag_handle, color: Colors.white70),
                  ),
                ),
              ),

              // text area + controls inside footer
              SizedBox(
                height: textAreaHeight - 24,
                child: Column(
                  children: [
                    // selectable text content
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        padding: const EdgeInsets.all(16),
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : SingleChildScrollView(
                                child: SelectableText(
                                  displayText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // footer controls bar
                    Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // language dropdown with meaningful names
                          DropdownButton<String>(
                            value: _targetLanguage,
                            items: _languageNames.entries.map((e) {
                              return DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _targetLanguage = val;
                                _translatedText = '';
                                _showTranslation = false;
                              });
                            },
                          ),

                          const Spacer(),

                          // translate toggle
                          IconButton(
                            tooltip: _showTranslation
                                ? 'Show original'
                                : 'Translate',
                            icon: _translating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _showTranslation
                                        ? Icons.translate_outlined
                                        : Icons.translate,
                                  ),
                            onPressed: (_loading || _translating)
                                ? null
                                : _toggleTranslation,
                          ),

                          // read aloud toggle
                          IconButton(
                            tooltip: _isSpeaking
                                ? 'Stop reading'
                                : 'Read aloud',
                            icon: Icon(
                              _isSpeaking ? Icons.stop : Icons.play_arrow,
                            ),
                            onPressed:
                                (_loading ||
                                    (_showTranslation &&
                                        _translatedText.isEmpty))
                                ? null
                                : _toggleReadAloud,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
