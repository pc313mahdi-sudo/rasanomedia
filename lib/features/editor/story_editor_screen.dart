import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _EditorTab { style, fonts, color, motion, background }

class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen>
    with TickerProviderStateMixin {
  final _text = TextEditingController(text: 'داستانت را\nزیباتر روایت کن');
  final _focus = FocusNode();
  final _canvasKey = GlobalKey();

  late final AnimationController _ambient;
  late final AnimationController _motionController;

  _EditorTab _tab = _EditorTab.color;
  int _background = 0;
  int _color = 0;
  int _font = 0;
  int _motion = 0;
  int _alignment = 1;
  int _textBackground = 0;
  // Font size is stored in a 360px-wide design coordinate system and scaled
  // to the actual story canvas, keeping typography proportional on every phone.
  double _fontSize = 34;
  double _x = .5;
  double _y = .48;
  double _rotation = 0;
  double _gestureFontSize = 34;
  double _gestureRotation = 0;
  bool _bold = true;
  bool _italic = false;
  bool _shadow = true;
  bool _transparent = true;
  bool _editingOnCanvas = false;
  bool _textSelected = false;
  Offset _toolbarOffset = Offset.zero;
  bool _busy = false;
  bool _toolSheetOpen = false;
  double _toolSheetHeight = 232;
  int _fontSubTab = 0; // 0: font library, 1: text settings
  int _colorSubTab = 0; // 0: color, 1: text style
  bool _showFavoriteColors = false;
  bool _showFavoriteStyles = false;
  String _fontSearch = '';
  String _fontCategory = 'همه';
  final Set<int> _favoriteFonts = <int>{};
  final Set<int> _favoriteColors = <int>{};
  final Set<int> _favoriteStyles = <int>{};
  final List<String> _customFontNames = <String>[];
  final List<String> _customFontFamilies = <String>[];
  final List<Color> _customColors = <Color>[];
  bool _glow = false;
  double _letterSpacing = 0;
  double _lineHeight = 1.35;
  final List<Map<String, dynamic>> _undoHistory = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _redoHistory = <Map<String, dynamic>>[];
  Timer? _autoSaveTimer;
  bool _restoringProject = false;

  static const _backgrounds = <List<Color>>[
    [Color(0xFF17152E), Color(0xFF573C91)],
    [Color(0xFF052D35), Color(0xFF178B83)],
    [Color(0xFF411C2B), Color(0xFFB34C65)],
    [Color(0xFF111827), Color(0xFF48566F)],
    [Color(0xFFF4D8C9), Color(0xFFB87570)],
    [Color(0xFF090B10), Color(0xFF333847)],
    [Color(0xFFFFF4E9), Color(0xFFE4D2BE)],
    [Color(0xFF12243A), Color(0xFF477BA7)],
  ];

  static const _colors = <Color>[
    Colors.white,
    Color(0xFFFFD166),
    Color(0xFFFF78A8),
    Color(0xFF8FE6FF),
    Color(0xFFB9F28C),
    Color(0xFF171717),
    Color(0xFFFF7043),
    Color(0xFFB8A0FF),
    Color(0xFF43D9B8),
    Color(0xFFFFF0DC),
  ];

  static const _baseFontNames = ['پیش‌فرض', 'مدرن', 'کلاسیک', 'ماشینی'];
  static const _baseFontFamilies = <String?>[null, 'sans-serif', 'serif', 'monospace'];

  List<String> get _allFontNames => [..._baseFontNames, ..._customFontNames];
  List<Color> get _allColors => [..._colors, ..._customColors];
  String? _fontFamilyAt(int index) => index < _baseFontFamilies.length
      ? _baseFontFamilies[index]
      : _customFontFamilies[index - _baseFontFamilies.length];

  static const _motionNames = ['بدون حرکت', 'محو', 'زوم', 'شناور', 'ضربان'];
  static const _motionIcons = [
    Icons.pause_circle_outline_rounded,
    Icons.blur_on_rounded,
    Icons.zoom_in_rounded,
    Icons.waves_rounded,
    Icons.favorite_rounded,
  ];

  static const _templateNames = ['مینیمال', 'تیتر برجسته', 'لطیف', 'نئونی', 'مجله‌ای'];
  static const _templateColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFD166),
    Color(0xFFFFB8C9),
    Color(0xFF8FE6FF),
    Color(0xFFFFF0DC),
  ];

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..value = .22; // Static ambient position: avoids a permanent full-screen repaint.
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProject());
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _ambient.dispose();
    _motionController.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  TextAlign get _textAlign => switch (_alignment) {
        0 => TextAlign.right,
        2 => TextAlign.left,
        _ => TextAlign.center,
      };

  TextStyle get _textStyle => TextStyle(
        fontFamily: _fontFamilyAt(_font),
        fontSize: _fontSize,
        height: _lineHeight,
        letterSpacing: _letterSpacing,
        color: _allColors[_color],
        fontWeight: _bold ? FontWeight.w900 : FontWeight.w500,
        fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
        shadows: _glow
            ? [Shadow(color: _allColors[_color].withValues(alpha: .85), blurRadius: 18)]
            : _shadow
                ? const [Shadow(color: Colors.black54, blurRadius: 15, offset: Offset(2, 5))]
                : null,
      );

  Map<String, dynamic> _captureProject() => <String, dynamic>{
        'text': _text.text,
        'background': _background,
        'color': _color,
        'font': _font,
        'motion': _motion,
        'alignment': _alignment,
        'textBackground': _textBackground,
        'fontSize': _fontSize,
        'x': _x,
        'y': _y,
        'rotation': _rotation,
        'bold': _bold,
        'italic': _italic,
        'shadow': _shadow,
        'glow': _glow,
        'transparent': _transparent,
        'letterSpacing': _letterSpacing,
        'lineHeight': _lineHeight,
        'favoriteFonts': _favoriteFonts.toList(),
        'favoriteColors': _favoriteColors.toList(),
        'favoriteStyles': _favoriteStyles.toList(),
        'customFontNames': _customFontNames,
        'customFontFamilies': _customFontFamilies,
        'customColors': _customColors.map((c) => c.value).toList(),
      };

  void _recordHistory() {
    if (_restoringProject) return;
    _undoHistory.add(_captureProject());
    if (_undoHistory.length > 60) _undoHistory.removeAt(0);
    _redoHistory.clear();
    _scheduleAutoSave();
  }

  void _restoreProject(Map<String, dynamic> data) {
    _restoringProject = true;
    setState(() {
      _text.text = (data['text'] as String?) ?? _text.text;
      _background = ((data['background'] as num?)?.toInt() ?? 0).clamp(0, _backgrounds.length - 1).toInt();
      _color = ((data['color'] as num?)?.toInt() ?? 0).clamp(0, _allColors.length - 1).toInt();
      _font = ((data['font'] as num?)?.toInt() ?? 0).clamp(0, _baseFontNames.length + _customFontNames.length - 1).toInt();
      _motion = ((data['motion'] as num?)?.toInt() ?? 0).clamp(0, _motionNames.length - 1).toInt();
      _alignment = ((data['alignment'] as num?)?.toInt() ?? 1).clamp(0, 2).toInt();
      _textBackground = ((data['textBackground'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt();
      _fontSize = (data['fontSize'] as num?)?.toDouble() ?? 34;
      _x = (data['x'] as num?)?.toDouble() ?? .5;
      _y = (data['y'] as num?)?.toDouble() ?? .48;
      _rotation = (data['rotation'] as num?)?.toDouble() ?? 0;
      _bold = data['bold'] as bool? ?? true;
      _italic = data['italic'] as bool? ?? false;
      _shadow = data['shadow'] as bool? ?? true;
      _glow = data['glow'] as bool? ?? false;
      _transparent = data['transparent'] as bool? ?? false;
      _letterSpacing = (data['letterSpacing'] as num?)?.toDouble() ?? 0;
      _lineHeight = (data['lineHeight'] as num?)?.toDouble() ?? 1.35;
      _favoriteFonts
        ..clear()
        ..addAll(((data['favoriteFonts'] as List?) ?? []).whereType<num>().map((e) => e.toInt()));
      _favoriteColors
        ..clear()
        ..addAll(((data['favoriteColors'] as List?) ?? []).whereType<num>().map((e) => e.toInt()));
      _favoriteStyles
        ..clear()
        ..addAll(((data['favoriteStyles'] as List?) ?? []).whereType<num>().map((e) => e.toInt()));
      _customFontNames
        ..clear()
        ..addAll(((data['customFontNames'] as List?) ?? []).whereType<String>());
      _customFontFamilies
        ..clear()
        ..addAll(((data['customFontFamilies'] as List?) ?? []).whereType<String>());
      _customColors
        ..clear()
        ..addAll(((data['customColors'] as List?) ?? []).whereType<num>().map((e) => Color(e.toInt())));
      _color = _color.clamp(0, _allColors.length - 1).toInt();
      _font = _font.clamp(0, _allFontNames.length - 1).toInt();
    });
    _restoringProject = false;
  }

  Future<File> _projectFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/rasayar_project.json');
  }

  Future<void> _loadProject() async {
    try {
      final file = await _projectFile();
      if (!await file.exists() || !mounted) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) _restoreProject(decoded);
    } catch (_) {
      // A missing or outdated autosave must never prevent opening the editor.
    }
  }

  Future<void> _saveProject({bool silent = false}) async {
    try {
      final file = await _projectFile();
      await file.writeAsString(jsonEncode(_captureProject()), flush: true);
      if (!silent && mounted) _toast('پروژه رسایار ذخیره شد؛ می‌توانی بعداً ادامه بدهی.');
    } catch (e) {
      if (mounted && !silent) _toast('ذخیره پروژه انجام نشد: $e');
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1100), () => _saveProject(silent: true));
  }

  void _undo() {
    if (_undoHistory.isEmpty) {
      _toast('تغییری برای بازگشت وجود ندارد.');
      return;
    }
    _redoHistory.add(_captureProject());
    final previous = _undoHistory.removeLast();
    _restoreProject(previous);
    _scheduleAutoSave();
  }

  void _redo() {
    if (_redoHistory.isEmpty) {
      _toast('تغییری برای انجام مجدد وجود ندارد.');
      return;
    }
    _undoHistory.add(_captureProject());
    final next = _redoHistory.removeLast();
    _restoreProject(next);
    _scheduleAutoSave();
  }

  Future<void> _goHome() async {
    await _saveProject(silent: true);
    if (mounted) widget.onBack();
  }

  Future<void> _addFontFamily() async {
    final name = TextEditingController();
    final family = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('افزودن فونت'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'نام نمایشی فونت')),
            const SizedBox(height: 8),
            TextField(controller: family, decoration: const InputDecoration(labelText: 'نام خانواده فونت نصب‌شده')),
            const SizedBox(height: 8),
            const Text('نام خانواده باید روی دستگاه نصب باشد. واردکردن فایل فونت در نسخه بعدی تکمیل می‌شود.', style: TextStyle(fontSize: 11)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('افزودن')),
          ],
        ),
      ),
    );
    if (accepted == true && name.text.trim().isNotEmpty && family.text.trim().isNotEmpty) {
      _recordHistory();
      setState(() {
        _customFontNames.add(name.text.trim());
        _customFontFamilies.add(family.text.trim());
        _font = _allFontNames.length - 1;
      });
      _scheduleAutoSave();
    }
    name.dispose();
    family.dispose();
  }

  void _selectTab(_EditorTab tab) {
    FocusScope.of(context).unfocus();
    setState(() {
      _editingOnCanvas = false;
      _textSelected = false;
      if (_toolSheetOpen && _tab == tab) {
        _toolSheetOpen = false;
      } else {
        _tab = tab;
        _toolSheetOpen = true;
      }
    });
  }

  void _selectTextOnCanvas() {
    _editOnCanvas();
  }

  void _deselectText() {
    if (!_textSelected || _editingOnCanvas) return;
    setState(() => _textSelected = false);
  }

  void _editOnCanvas() {
    if (_editingOnCanvas) return;
    _recordHistory();
    setState(() {
      _textSelected = true;
      _editingOnCanvas = true;
      // Keep the active tool panel and both side controls in place while typing.
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_text.selection.isCollapsed && _text.selection.baseOffset == 0) {
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      }
      _focus.requestFocus();
    });
  }

  void _finishCanvasEditing() {
    FocusScope.of(context).unfocus();
    if (mounted) {
      setState(() {
        _editingOnCanvas = false;
        _textSelected = true;
      });
      _scheduleAutoSave();
    }
  }

  void _openToolFromSelection(_EditorTab tab) {
    FocusScope.of(context).unfocus();
    setState(() {
      _editingOnCanvas = false;
      _textSelected = false;
      _tab = tab;
      _toolSheetOpen = true;
    });
  }

  Future<Uint8List?> _renderPng() async {
    FocusScope.of(context).unfocus();
    if (_editingOnCanvas || _toolSheetOpen) {
      setState(() {
        _editingOnCanvas = false;
        _textSelected = false;
        _toolSheetOpen = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _renderPng();
      if (bytes == null) throw Exception('تصویر خروجی آماده نشد.');
      await Gal.putImageBytes(
        bytes,
        name: 'rasayar_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) _toast('استوری با موفقیت در گالری ذخیره شد.');
    } on GalException catch (e) {
      if (mounted) _toast('ذخیره‌سازی انجام نشد: ${e.type.name}');
    } catch (e) {
      if (mounted) _toast('خطا در ذخیره تصویر: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _renderPng();
      if (bytes == null) throw Exception('تصویر خروجی آماده نشد.');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rasayar_story.png');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'ساخته‌شده با رسایار');
    } catch (e) {
      if (mounted) _toast('اشتراک‌گذاری ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _applyTemplate(int index) {
    _recordHistory();
    setState(() {
      _fontSize = [32.0, 46.0, 34.0, 40.0, 38.0][index];
      _color = index;
      _bold = index != 2;
      _italic = index == 2;
      _shadow = index != 0;
      _textBackground = 0;
    });
    _scheduleAutoSave();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF1F2F6)
            : const Color(0xFF090B12),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final keyboardVisible = keyboardInset > 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _ambient,
                      builder: (_, __) => CustomPaint(
                        painter: _AmbientPainter(_ambient.value),
                      ),
                    ),
                  ),
                  Column(
                      children: [
                        _topBar(),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(child: _previewArea()),
                              Positioned(
                                  right: 7,
                                  top: 12,
                                  child: RepaintBoundary(child: _glassToolRail()),
                                ),
                            ],
                          ),
                        ),
                        if (!keyboardVisible) _exportBar(),
                      ],
                    ),
                  if (_textSelected && !_editingOnCanvas && !keyboardVisible)
                    _floatingTextToolbar(),
                  Positioned(
                    left: 5,
                    top: constraints.maxHeight * .34,
                    child: _leftSizeSlider(),
                  ),
                  if (_toolSheetOpen)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: keyboardVisible ? keyboardInset : 0,
                      child: IgnorePointer(
                        ignoring: !_toolSheetOpen,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 330),
                          curve: Curves.easeOutCubic,
                          offset: _toolSheetOpen ? Offset.zero : const Offset(0, 1),
                          child: _toolSheet(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
        child: Row(
          children: [
            _roundButton(Icons.home_rounded, _goHome),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'استودیوی استوری',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'RASAYAR  •  CREATIVE CANVAS',
                    style: TextStyle(
                      color: Color(0xFF9295A4),
                      fontSize: 8,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            _roundButton(Icons.undo_rounded, _undo),
            const SizedBox(width: 5),
            _roundButton(Icons.redo_rounded, _redo),
            const SizedBox(width: 5),
            _roundButton(Icons.save_rounded, () => _saveProject()),
            const SizedBox(width: 5),
            if (_editingOnCanvas)
              _roundButton(Icons.check_rounded, _finishCanvasEditing)
            else
              _roundButton(Icons.more_horiz_rounded, _showMore),
          ],
        ),
      );

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white.withValues(alpha: .82)
            : const Color(0xFF202330),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 39,
            height: 39,
            child: Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.light
                  ? const Color(0xFF303648)
                  : Colors.white,
              size: 19,
            ),
          ),
        ),
      );

  Widget _glassToolRail() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tools = <({ _EditorTab tab, IconData icon, String label })>[
      (tab: _EditorTab.color, icon: Icons.palette_rounded, label: 'رنگ'),
      (tab: _EditorTab.fonts, icon: Icons.font_download_rounded, label: 'فونت'),
      (tab: _EditorTab.motion, icon: Icons.animation_rounded, label: 'حرکت'),
      (tab: _EditorTab.background, icon: Icons.wallpaper_rounded, label: 'بوم'),
    ];

    return ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
          child: Container(
            width: 56,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            decoration: BoxDecoration(
              color: isLight ? Colors.white.withValues(alpha: .66) : const Color(0xFF202633).withValues(alpha: .52),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: (isLight ? Colors.black : Colors.white).withValues(alpha: .10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF713B).withValues(alpha: .10),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Colors.black38,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final tool in tools) ...[
                  _glassRailItem(tool.tab, tool.icon, tool.label),
                  if (tool != tools.last) const SizedBox(height: 3),
                ],
              ],
            ),
          ),
        ),
    );
  }

  Widget _glassRailItem(_EditorTab tab, IconData icon, String label) {
    final selected = _toolSheetOpen && _tab == tab;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: () => _selectTab(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFA66F), Color(0xFFE84D24)],
                )
              : null,
          color: selected
              ? null
              : (isLight
                  ? Colors.black.withValues(alpha: .035)
                  : Colors.white.withValues(alpha: .035)),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: .38)
                : (isLight
                    ? Colors.black.withValues(alpha: .08)
                    : Colors.white.withValues(alpha: .07)),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF713B).withValues(alpha: .35),
                    blurRadius: 13,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: selected ? 1.10 : 1,
              child: _ThreeDIcon(icon: icon, active: selected),
            ),
            const SizedBox(height: 1),
            SizedBox(
              width: 42,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: selected ? Colors.white : (isLight ? const Color(0xFF34394A) : Colors.white70),
                    fontSize: 7,
                    height: 1,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _toolTitle => switch (_tab) {
        _EditorTab.style => 'رنگ و استایل',
        _EditorTab.fonts => 'فونت و تنظیمات متن',
        _EditorTab.color => 'رنگ و استایل',
        _EditorTab.motion => 'انیمیشن متن',
        _EditorTab.background => 'تنظیمات بوم',
      };

  Widget _toolSheet() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxSheetHeight = screenHeight * .58;
    final sheetHeight = _toolSheetHeight.clamp(214.0, maxSheetHeight);
    return SizedBox(
      height: sheetHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 11, sigmaY: 11),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isLight ? const Color(0xFFFFFFFF) : const Color(0xFF303747)).withValues(alpha: isLight ? .42 : .30),
                  (isLight ? const Color(0xFFE9ECF3) : const Color(0xFF151923)).withValues(alpha: isLight ? .50 : .40),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .14),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 28,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _toolSheetHeight = (_toolSheetHeight - details.delta.dy)
                          .clamp(214.0, maxSheetHeight);
                    });
                  },
                  onDoubleTap: () => setState(() {
                    _toolSheetHeight = _toolSheetHeight < screenHeight * .42
                        ? screenHeight * .54
                        : screenHeight * .32;
                  }),
                  child: SizedBox(
                    width: double.infinity,
                    height: 13,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .42),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFA66F), Color(0xFFE84D24)],
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        switch (_tab) {
                          _EditorTab.style => Icons.palette_rounded,
                          _EditorTab.fonts => Icons.font_download_rounded,
                          _EditorTab.color => Icons.palette_rounded,
                          _EditorTab.motion => Icons.animation_rounded,
                          _EditorTab.background => Icons.wallpaper_rounded,
                        },
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _toolTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isLight ? const Color(0xFF242838) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (_tab == _EditorTab.fonts) ...[
                      SizedBox(
                        width: 88,
                        height: 29,
                        child: TextField(
                          onTap: () {
                            if (_fontSubTab != 0) setState(() => _fontSubTab = 0);
                          },
                          onChanged: (value) => setState(() => _fontSearch = value.trim()),
                          style: TextStyle(color: isLight ? const Color(0xFF242838) : Colors.white, fontSize: 8.5),
                          decoration: InputDecoration(
                            hintText: 'جستجو',
                            hintStyle: TextStyle(color: isLight ? Colors.black45 : Colors.white54, fontSize: 7),
                            prefixIcon: Icon(Icons.search_rounded, color: isLight ? Colors.black54 : Colors.white70, size: 14),
                            prefixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            filled: true,
                            fillColor: isLight ? Colors.black.withValues(alpha: .045) : Colors.white.withValues(alpha: .07),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: (isLight ? Colors.black : Colors.white).withValues(alpha: .14))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: (isLight ? Colors.black : Colors.white).withValues(alpha: .14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton.filledTonal(
                          tooltip: 'افزودن فونت',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: _addFontFamily,
                          icon: const Icon(Icons.add_rounded, size: 17),
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: 'بستن تنظیمات',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _toolSheetOpen = false),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      color: isLight ? const Color(0xFF4C5262) : Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey(_tab),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white.withValues(alpha: .18)
                            : Colors.white.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .09),
                        ),
                      ),
                      child: _panelContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewArea() => LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth - 34;
          final maxH = constraints.maxHeight - 6;
          final width = (maxH * 9 / 16).clamp(112.0, maxW).toDouble();
          return Center(
            child: SizedBox(
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: _backgrounds[_background][1]
                                .withValues(alpha: .30),
                            blurRadius: 38,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    key: _canvasKey,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _transparent ? Colors.transparent : null,
                          gradient: _transparent
                              ? null
                              : LinearGradient(
                                  colors: _backgrounds[_background],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, canvas) => Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _deselectText,
                                ),
                              ),
                              if (!_transparent) ...[
                                Positioned(
                                  top: 18,
                                  right: 16,
                                  child: _FloatingGlyph(
                                    controller: _ambient,
                                    icon: Icons.auto_awesome_rounded,
                                    size: 28,
                                  ),
                                ),
                                Positioned(
                                  bottom: 30,
                                  left: 18,
                                  child: _FloatingGlyph(
                                    controller: _ambient,
                                    icon: Icons.blur_on_rounded,
                                    size: 48,
                                    reverse: true,
                                  ),
                                ),
                              ],
                              Align(
                                alignment: Alignment(
                                  (_x * 2 - 1).clamp(-.82, .82).toDouble(),
                                  (_y * 2 - 1).clamp(-.82, .82).toDouble(),
                                ),
                                child: GestureDetector(
                                  onTap: _editingOnCanvas ? null : _editOnCanvas,
                                  onScaleStart: _editingOnCanvas
                                      ? null
                                      : (_) {
                                          _recordHistory();
                                          _gestureFontSize = _fontSize;
                                          _gestureRotation = _rotation;
                                        },
                                  onScaleUpdate: _editingOnCanvas
                                      ? null
                                      : (details) {
                                          setState(() {
                                            _x = (_x +
                                                    details.focalPointDelta.dx /
                                                        canvas.maxWidth)
                                                .clamp(.12, .88)
                                                .toDouble();
                                            _y = (_y +
                                                    details.focalPointDelta.dy /
                                                        canvas.maxHeight)
                                                .clamp(.12, .88)
                                                .toDouble();
                                            // Use the gesture's starting size;
                                            // multiplying each update caused exponential jumps.
                                            _fontSize = (_gestureFontSize *
                                                    details.scale)
                                                .clamp(18, 68)
                                                .toDouble();
                                            _rotation = (_gestureRotation +
                                                    details.rotation)
                                                .clamp(-.5, .5)
                                                .toDouble();
                                          });
                                          _scheduleAutoSave();
                                        },
                                  child: SizedBox(
                                    width: canvas.maxWidth * .88,
                                    child: AnimatedBuilder(
                                      animation: _motionController,
                                      builder: (_, child) {
                                        final t = _motionController.value;
                                        final opacity = _motion == 1
                                            ? .55 + .45 * t
                                            : 1.0;
                                        final scale = _motion == 2
                                            ? .94 + .12 * t
                                            : _motion == 4
                                                ? 1 + .025 * (1 - (2 * t - 1).abs())
                                                : 1.0;
                                        final dy = _motion == 3
                                            ? -5 * (1 - (2 * t - 1).abs())
                                            : 0.0;
                                        return Opacity(
                                          opacity: opacity,
                                          child: Transform.translate(
                                            offset: Offset(0, dy),
                                            child: Transform.rotate(
                                              angle: _rotation,
                                              child: Transform.scale(
                                                scale: scale,
                                                child: child,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxHeight: canvas.maxHeight * .52,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _textBackground == 1
                                              ? Colors.black.withValues(alpha: .30)
                                              : _textBackground == 2
                                                  ? Colors.white.withValues(alpha: .18)
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(13),
                                          border: _textSelected || _editingOnCanvas
                                              ? Border.all(
                                                  color: const Color(0xFFFF8B56),
                                                  width: 1.4,
                                                )
                                              : null,
                                        ),
                                        child: _editingOnCanvas
                                            ? TextField(
                                                controller: _text,
                                                focusNode: _focus,
                                                autofocus: true,
                                                minLines: 1,
                                                maxLines: null,
                                                keyboardType: TextInputType.multiline,
                                                textInputAction: TextInputAction.newline,
                                                enableInteractiveSelection: true,
                                                textDirection: TextDirection.rtl,
                                                textAlign: _textAlign,
                                                style: _canvasTextStyle(
                                                    canvas.maxWidth),
                                                onChanged: (_) { setState(() {}); _scheduleAutoSave(); },
                                                decoration: const InputDecoration(
                                                  hintText: 'متن را بنویس...',
                                                  hintStyle: TextStyle(
                                                      color: Colors.white70),
                                                  border: InputBorder.none,
                                                  filled: false,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              )
                                            : Text(
                                                _text.text.isEmpty
                                                    ? 'متن استوری شما'
                                                    : _text.text,
                                                textDirection: TextDirection.rtl,
                                                textAlign: _textAlign,
                                                maxLines: 5,
                                                overflow: TextOverflow.fade,
                                                style: _canvasTextStyle(
                                                    canvas.maxWidth),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (!_transparent)
                                Positioned(
                                  bottom: 12,
                                  left: 0,
                                  right: 0,
                                  child: Text(
                                    'RASAYAR',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: .32),
                                      letterSpacing: 4,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: _canvasBadge(_transparent ? 'PNG شفاف' : '9:16'),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _leftSizeSlider() => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
          child: Container(
            width: 38,
            height: 166,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF252B39)).withValues(alpha: .56),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: (Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white).withValues(alpha: .14),
              ),
            ),
            child: Column(children: [
              Icon(Icons.text_increase_rounded, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF41485A) : Colors.white70, size: 16),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFFF8A55),
                      inactiveTrackColor: (Theme.of(context).brightness == Brightness.light
                          ? Colors.black
                          : Colors.white).withValues(alpha: .20),
                      thumbColor: const Color(0xFFFFA071),
                      overlayColor: const Color(0xFFFF713B).withValues(alpha: .14),
                      trackHeight: 2.5,
                    ),
                    child: Slider(
                    value: _fontSize.clamp(18, 68),
                    min: 18,
                    max: 68,
                    onChangeStart: (_) => _recordHistory(),
                    onChanged: (value) {
                      setState(() => _fontSize = value);
                      _scheduleAutoSave();
                    },
                    ),
                  ),
                ),
              ),
              Text(_fontSize.round().toString(), style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF34394A) : Colors.white, fontSize: 9)),
            ]),
          ),
        ),
      );

  Widget _floatingTextToolbar() {
    return Positioned(
      right: (14 + _toolbarOffset.dx).clamp(6.0, 220.0),
      bottom: (14 + _toolbarOffset.dy).clamp(6.0, 360.0),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _toolbarOffset = Offset(
              (_toolbarOffset.dx - details.delta.dx).clamp(-8.0, 190.0),
              (_toolbarOffset.dy - details.delta.dy).clamp(-8.0, 320.0),
            );
          });
        },
        child: Material(
          color: const Color(0xFF202330),
          elevation: 16,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFF945E).withValues(alpha: .65)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .28),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.drag_indicator_rounded,
                      color: Colors.white38, size: 18),
                ),
                _floatingToolButton(
                  Icons.edit_rounded,
                  'ویرایش متن',
                  _editOnCanvas,
                  active: true,
                ),
                _floatingToolButton(
                  Icons.text_fields_rounded,
                  'فونت',
                  () => _openToolFromSelection(_EditorTab.fonts),
                ),
                _floatingToolButton(
                  Icons.palette_rounded,
                  'رنگ',
                  () => _openToolFromSelection(_EditorTab.color),
                ),
                _floatingToolButton(
                  Icons.remove_circle_outline_rounded,
                  'کوچک‌تر',
                  () { _recordHistory(); setState(() => _fontSize = (_fontSize - 2).clamp(18, 68).toDouble()); },
                ),
                _floatingToolButton(
                  Icons.add_circle_outline_rounded,
                  'بزرگ‌تر',
                  () { _recordHistory(); setState(() => _fontSize = (_fontSize + 2).clamp(18, 68).toDouble()); },
                ),
                _floatingToolButton(
                  Icons.check_circle_outline_rounded,
                  'پایان انتخاب',
                  _deselectText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingToolButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 37,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFF713B).withValues(alpha: .20)
                : Colors.white.withValues(alpha: .045),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? const Color(0xFFFFA071) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _canvasBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .38),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _panelContent() {
    switch (_tab) {
      case _EditorTab.style:
        return _colorPanel();
      case _EditorTab.fonts:
        return _fontPanel();
      case _EditorTab.color:
        return _colorPanel();
      case _EditorTab.motion:
        return _motionPanel();
      case _EditorTab.background:
        return _backgroundPanel();
    }
  }

  Widget _templatePanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'استایل‌های آماده متن',
            style: TextStyle(color: Colors.white70, fontSize: 9),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _templateNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _applyTemplate(i),
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: i == 3
                          ? const [Color(0xFF183B54), Color(0xFF6A3E87)]
                          : const [Color(0xFF343848), Color(0xFF242735)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _templateNames[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _templateColors[i],
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        shadows: i == 3
                            ? [
                                Shadow(
                                  color: _templateColors[i],
                                  blurRadius: 10,
                                )
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  TextStyle _canvasTextStyle(double canvasWidth) => _textStyle.copyWith(
        fontSize: _fontSize * (canvasWidth / 360),
      );

  Widget _keyboardEditBar() => Padding(
        padding: const EdgeInsets.fromLTRB(13, 7, 13, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'متن را همین‌جا ویرایش کن؛ پیش‌نمایش ثابت می‌ماند',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _finishCanvasEditing,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('تأیید'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF713B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 9,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _fontPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _fontSubTabButton('کتابخانه فونت', 0)),
              const SizedBox(width: 8),
              Expanded(child: _fontSubTabButton('تنظیمات متن', 1)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _fontSubTab == 0
                  ? _fontLibraryPanel(key: const ValueKey('font-library'))
                  : _fontTextSettingsPanel(key: const ValueKey('font-text-settings')),
            ),
          ),
        ],
      );

  Widget _fontSubTabButton(String label, int value) => GestureDetector(
        onTap: () => setState(() => _fontSubTab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _fontSubTab == value
                ? const Color(0xFFFF713B).withValues(alpha: .82)
                : Colors.white.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _fontSubTab == value
                  ? Colors.white.withValues(alpha: .28)
                  : Colors.white.withValues(alpha: .10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: _fontSubTab == value ? 1 : .72),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );

  Widget _fontLibraryPanel({Key? key}) => Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['همه', 'علاقه‌مندی‌ها', 'فارسی', 'انگلیسی', 'عربی'].map((category) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: ChoiceChip(
                  label: Text(category, style: const TextStyle(fontSize: 9)),
                  selected: _fontCategory == category,
                  onSelected: (_) => setState(() => _fontCategory = category),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selectedColor: const Color(0xFFFF713B),
                  backgroundColor: Colors.white.withValues(alpha: .055),
                  labelStyle: TextStyle(color: _fontCategory == category ? Colors.white : Colors.white70),
                  side: BorderSide(color: Colors.white.withValues(alpha: .10)),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 78,
            child: Builder(builder: (context) {
              final indices = List<int>.generate(_allFontNames.length, (i) => i).where((i) {
                final name = _allFontNames[i].toLowerCase();
                final queryMatch = _fontSearch.isEmpty || name.contains(_fontSearch.toLowerCase());
                final favoriteMatch = _fontCategory != 'علاقه‌مندی‌ها' || _favoriteFonts.contains(i);
                final categoryMatch = switch (_fontCategory) {
                  'فارسی' => i == 0 || i == 1,
                  'انگلیسی' => i == 1 || i == 2 || i == 3,
                  'عربی' => i == 0 || i == 2,
                  _ => true,
                };
                return queryMatch && favoriteMatch && categoryMatch;
              }).toList();
              if (indices.isEmpty) return const Center(child: Text('فونتی پیدا نشد', style: TextStyle(color: Colors.white60, fontSize: 10)));
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: indices.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, item) {
                  final i = indices[item];
                  return GestureDetector(
                    onTap: () {
                      _recordHistory();
                      setState(() => _font = i);
                      _scheduleAutoSave();
                    },
                    child: Container(
                      width: 76,
                      height: 72,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _font == i
                              ? const [Color(0xFFFFA570), Color(0xFFD55A34)]
                              : const [Color(0xFF313949), Color(0xFF1A2030)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _font == i ? Colors.white.withValues(alpha: .52) : Colors.white.withValues(alpha: .11),
                          width: _font == i ? 1.2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_font == i ? const Color(0xFFFF713B) : Colors.black).withValues(alpha: _font == i ? .18 : .10),
                            blurRadius: 9,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(children: [
                        Positioned(
                          top: -1,
                          left: -2,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                            onPressed: () {
                              _recordHistory();
                              setState(() {
                                if (_favoriteFonts.contains(i)) {
                                  _favoriteFonts.remove(i);
                                } else {
                                  _favoriteFonts.add(i);
                                }
                              });
                              _scheduleAutoSave();
                            },
                            icon: Icon(_favoriteFonts.contains(i) ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 12, color: _favoriteFonts.contains(i) ? const Color(0xFFFF82A4) : Colors.white70),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 18),
                            child: Text(
                              'Aa',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(fontFamily: _fontFamilyAt(i), color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .17),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.white.withValues(alpha: .08)),
                            ),
                            child: Text(_allFontNames[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      );

  Widget _fontTextSettingsPanel({Key? key}) => SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _settingsSection(
              'تراز و چیدمان',
              Row(
                children: [
                  _alignButton(0, Icons.format_align_right_rounded),
                  _alignButton(1, Icons.format_align_center_rounded),
                  _alignButton(2, Icons.format_align_left_rounded),
                  const Spacer(),
                  const Text('اندازه از نوار سمت چپ', style: TextStyle(color: Colors.white54, fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(height: 9),
            _settingsSection(
              'ظاهر متن',
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _miniToggle('ضخیم', _bold, (v) { _recordHistory(); setState(() => _bold = v); _scheduleAutoSave(); }),
                  _miniToggle('مورب', _italic, (v) { _recordHistory(); setState(() => _italic = v); _scheduleAutoSave(); }),
                  _miniToggle('سایه', _shadow, (v) { _recordHistory(); setState(() => _shadow = v); _scheduleAutoSave(); }),
                  _miniToggle('درخشش', _glow, (v) { _recordHistory(); setState(() => _glow = v); _scheduleAutoSave(); }),
                ],
              ),
            ),
            const SizedBox(height: 9),
            _settingsSection(
              'فاصله‌ها',
              Column(
                children: [
                  _sliderRow('فاصله حروف', _letterSpacing, -1, 8, (v) { setState(() => _letterSpacing = v); _scheduleAutoSave(); }, onStart: _recordHistory),
                  _sliderRow('فاصله خطوط', _lineHeight, 0.8, 2, (v) { setState(() => _lineHeight = v); _scheduleAutoSave(); }, onStart: _recordHistory),
                ],
              ),
            ),
            const SizedBox(height: 9),
            _settingsSection(
              'زمینه متن',
              Row(children: [
                _miniChoice('بدون', 0),
                _miniChoice('تیره', 1),
                _miniChoice('روشن', 2),
              ]),
            ),
          ],
        ),
      );

  Widget _settingsSection(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            child,
          ],
        ),
      );

  Widget _colorPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _colorSubTabButton('رنگ', 0)),
              const SizedBox(width: 7),
              Expanded(child: _colorSubTabButton('استایل', 1)),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _colorSubTab == 0
                  ? _colorPalettePanel(key: const ValueKey('color-palette'))
                  : _colorStylePanel(key: const ValueKey('color-style')),
            ),
          ),
        ],
      );

  Widget _colorSubTabButton(String label, int value) => GestureDetector(
        onTap: () => setState(() => _colorSubTab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _colorSubTab == value
                ? const Color(0xFFFF713B).withValues(alpha: .88)
                : Colors.white.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: _colorSubTab == value ? .25 : .10)),
          ),
          child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: _colorSubTab == value ? 1 : .72), fontSize: 9, fontWeight: FontWeight.w800)),
        ),
      );

  Widget _colorPalettePanel({Key? key}) => Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('پالت رنگ', style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: _showFavoriteColors ? 'نمایش همه رنگ‌ها' : 'علاقه‌مندی‌ها',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 30, height: 28),
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showFavoriteColors = !_showFavoriteColors),
                icon: Icon(_showFavoriteColors ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 17, color: const Color(0xFFFF7298)),
              ),
              InkWell(
                onTap: _addCustomColor,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFA66F), Color(0xFFE84D24)]),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF713B).withValues(alpha: .22), blurRadius: 10)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.colorize_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text('انتخاب رنگ دلخواه', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ],
          ),
          Expanded(
            child: Builder(builder: (context) {
              final indices = List<int>.generate(_allColors.length, (i) => i)
                  .where((i) => !_showFavoriteColors || _favoriteColors.contains(i))
                  .toList();
              if (indices.isEmpty) {
                return Center(
                  child: Text(
                    _showFavoriteColors ? 'هنوز رنگی به علاقه‌مندی‌ها اضافه نشده' : 'رنگی برای نمایش وجود ندارد',
                    style: const TextStyle(color: Colors.white60, fontSize: 9),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: indices.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, item) {
                  final i = indices[item];
                  final color = _allColors[i];
                  final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                  return SizedBox(
                    width: 47,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () { _recordHistory(); setState(() => _color = i); _scheduleAutoSave(); },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 31,
                            height: 31,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: _color == i ? const Color(0xFFFF8B56) : Colors.white38, width: _color == i ? 3 : 1),
                              boxShadow: _color == i ? [BoxShadow(color: color.withValues(alpha: .36), blurRadius: 10)] : null,
                            ),
                            child: _color == i ? Icon(Icons.check_rounded, size: 14, color: color.computeLuminance() > .5 ? Colors.black : Colors.white) : null,
                          ),
                        ),
                        SizedBox(
                          height: 18,
                          child: IconButton(
                            tooltip: _favoriteColors.contains(i) ? 'حذف از علاقه‌مندی‌ها' : 'افزودن به علاقه‌مندی‌ها',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _recordHistory();
                              setState(() {
                                if (_favoriteColors.contains(i)) {
                                  _favoriteColors.remove(i);
                                } else {
                                  _favoriteColors.add(i);
                                }
                              });
                              _scheduleAutoSave();
                            },
                            icon: Icon(_favoriteColors.contains(i) ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 12, color: _favoriteColors.contains(i) ? const Color(0xFFFF7298) : Colors.white60),
                          ),
                        ),
                        Text(hex, maxLines: 1, style: const TextStyle(color: Colors.white54, fontSize: 6)),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      );

  Widget _colorStylePanel({Key? key}) => Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('استایل‌های آماده', style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'نمایش علاقه‌مندی‌ها',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 29, height: 27),
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showFavoriteStyles = !_showFavoriteStyles),
                icon: Icon(_showFavoriteStyles ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: const Color(0xFFFF7298), size: 17),
              ),
            ],
          ),
          SizedBox(
            height: 94,
            child: Builder(builder: (context) {
              final styles = List<int>.generate(_templateNames.length, (i) => i)
                  .where((i) => !_showFavoriteStyles || _favoriteStyles.contains(i)).toList();
              if (styles.isEmpty) {
                return const Center(child: Text('هنوز استایلی ذخیره نکرده‌ای', style: TextStyle(color: Colors.white60, fontSize: 9)));
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 3),
                itemCount: styles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, item) {
                  final i = styles[item];
                  final accent = _templateColors[i];
                  final isFavorite = _favoriteStyles.contains(i);
                  return SizedBox(
                    width: 78,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _applyTemplate(i),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: i == 3
                                  ? const [Color(0xFF48557B), Color(0xFF8853B4)]
                                  : [const Color(0xFF313949), const Color(0xFF1A2030)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent.withValues(alpha: .32), width: 1),
                            boxShadow: [
                              BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 7, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 7,
                                right: 8,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                child: IconButton(
                                  tooltip: isFavorite ? 'حذف از علاقه‌مندی‌ها' : 'افزودن به علاقه‌مندی‌ها',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                  onPressed: () {
                                    _recordHistory();
                                    setState(() {
                                      if (isFavorite) { _favoriteStyles.remove(i); } else { _favoriteStyles.add(i); }
                                    });
                                    _scheduleAutoSave();
                                  },
                                  icon: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: const Color(0xFFFF82A4), size: 12),
                                ),
                              ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(5, 14, 5, 18),
                                  child: Text(
                                    'Aa',
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 22,
                                      height: 1.0,
                                      fontWeight: FontWeight.w900,
                                      shadows: i == 3 ? [Shadow(color: accent.withValues(alpha: .85), blurRadius: 10)] : null,
                                      fontStyle: i == 2 ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                right: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withValues(alpha: .08)),
                                  ),
                                  child: Text(
                                    _templateNames[i],
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      );

  Future<void> _addCustomColor() async {
    HSVColor hsv = HSVColor.fromColor(_allColors[_color]);
    Color pickerColor = hsv.toColor();
    final controller = TextEditingController(text: _hexColor(pickerColor));
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setPickerState) {
            void updateColor(HSVColor next) {
              setPickerState(() {
                hsv = next;
                pickerColor = hsv.toColor();
                final hex = _hexColor(pickerColor);
                controller.value = TextEditingValue(
                  text: hex,
                  selection: TextSelection.collapsed(offset: hex.length),
                );
              });
            }

            final isLight = Theme.of(context).brightness == Brightness.light;
            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.sizeOf(context).height * .72,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF5F6FA).withValues(alpha: .97) : const Color(0xFF171B27).withValues(alpha: .97),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: .18)),
                ),
                child: Column(
                  children: [
                    Container(width: 42, height: 4, decoration: BoxDecoration(color: isLight ? Colors.black26 : Colors.white38, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(width: 38, height: 38, decoration: BoxDecoration(color: pickerColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isLight ? Colors.black12 : Colors.white24))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('انتخاب رنگ دلخواه', style: TextStyle(color: isLight ? const Color(0xFF202638) : Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                          Text('رنگ را آزادانه انتخاب کن یا کد HEX را وارد کن', style: TextStyle(color: isLight ? Colors.black54 : Colors.white60, fontSize: 9)),
                        ])),
                        IconButton(onPressed: () => Navigator.pop(sheetContext, false), icon: Icon(Icons.close_rounded, color: isLight ? Colors.black54 : Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: SizedBox(
                                height: 190,
                                width: double.infinity,
                                child: _SaturationValuePicker(
                                  hue: hsv.hue,
                                  saturation: hsv.saturation,
                                  value: hsv.value,
                                  onChanged: (sat, val) => updateColor(hsv.withSaturation(sat).withValue(val)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _pickerLabel('طیف رنگ'),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: SizedBox(
                                height: 30,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          Color(0xFFFF0000), Color(0xFFFFFF00),
                                          Color(0xFF00FF00), Color(0xFF00FFFF),
                                          Color(0xFF0000FF), Color(0xFFFF00FF),
                                          Color(0xFFFF0000),
                                        ]),
                                      ),
                                      child: SizedBox.expand(),
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 10,
                                        activeTrackColor: Colors.transparent,
                                        inactiveTrackColor: Colors.transparent,
                                        thumbColor: Colors.white,
                                        overlayColor: Colors.white24,
                                      ),
                                      child: Slider(value: hsv.hue, min: 0, max: 360, onChanged: (v) => updateColor(hsv.withHue(v))),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _pickerLabel('شفافیت رنگ'),
                            Slider(
                              value: hsv.alpha,
                              onChanged: (v) => updateColor(hsv.withAlpha(v)),
                              activeColor: pickerColor,
                              inactiveColor: Colors.white24,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(color: isLight ? const Color(0xFF202638) : Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
                                    onChanged: (value) {
                                      try {
                                        var hex = value.trim().replaceAll('#', '');
                                        if (hex.length == 6) hex = 'FF$hex';
                                        if (hex.length == 8) {
                                          final parsed = Color(int.parse(hex, radix: 16));
                                          setPickerState(() { pickerColor = parsed; hsv = HSVColor.fromColor(parsed); });
                                        }
                                      } catch (_) {}
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'کد رنگ HEX',
                                      hintText: '#FF713B',
                                      prefixIcon: const Icon(Icons.tag_rounded),
                                      filled: true,
                                      fillColor: isLight ? Colors.white : Colors.white.withValues(alpha: .06),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(width: 50, height: 50, decoration: BoxDecoration(color: pickerColor, shape: BoxShape.circle, border: Border.all(color: isLight ? Colors.black12 : Colors.white30), boxShadow: [BoxShadow(color: pickerColor.withValues(alpha: .35), blurRadius: 16)])),
                              ],
                            ),
                            const SizedBox(height: 13),
                            _pickerLabel('رنگ‌های پیشنهادی'),
                            SizedBox(
                              height: 42,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _colors.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => GestureDetector(
                                  onTap: () { hsv = HSVColor.fromColor(_colors[i]); updateColor(hsv); },
                                  child: Container(width: 34, decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.5))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('افزودن رنگ به پالت'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF713B), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (accepted == true) {
      try {
        var hex = controller.text.trim().replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        if (hex.length != 8) throw const FormatException('Invalid HEX color');
        final color = Color(int.parse(hex, radix: 16));
        _recordHistory();
        setState(() { _customColors.add(color); _color = _allColors.length - 1; _showFavoriteColors = false; });
        _scheduleAutoSave();
      } catch (_) {
        if (mounted) _toast('کد رنگ معتبر نیست. از قالب #RRGGBB استفاده کن.');
      }
    }
    controller.dispose();
  }

  Widget _pickerLabel(String label) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 3, top: 3),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  String _hexColor(Color color) => '#${color.value.toRadixString(16).substring(2).toUpperCase()}';

  Widget _colorPickerSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Row(
        children: [
          SizedBox(width: 54, child: Text(label, style: const TextStyle(fontSize: 9))),
          Expanded(child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, onChanged: onChanged)),
        ],
      );

  Widget _motionPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'انیمیشن متن در پیش‌نمایش',
            style: TextStyle(color: Colors.white70, fontSize: 9),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 49,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _motionNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  _recordHistory();
                  setState(() => _motion = i);
                  _scheduleAutoSave();
                  if (i == 0) {
                    _motionController.stop();
                    _motionController.value = 0;
                  } else {
                    _motionController.repeat(reverse: true);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _motion == i
                        ? const Color(0xFFFF713B)
                        : const Color(0xFF343848),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_motionIcons[i], color: Colors.white, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        _motionNames[i],
                        style: const TextStyle(
                            color: Colors.white, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _backgroundPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'پس‌زمینه استوری',
                style: TextStyle(color: Colors.white70, fontSize: 9),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () { _recordHistory(); setState(() => _transparent = !_transparent); },
                child: Row(
                  children: [
                    Icon(
                      _transparent
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: const Color(0xFFFF9A68),
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'خروجی شفاف PNG',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _backgrounds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () { _recordHistory(); setState(() {
                  _background = i;
                  _transparent = false;
                }); _scheduleAutoSave(); },
                child: Container(
                  width: 45,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _backgrounds[i],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: _background == i && !_transparent
                          ? const Color(0xFFFF8B56)
                          : Colors.white12,
                      width: 2,
                    ),
                  ),
                  child: _background == i && !_transparent
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 17)
                      : null,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _alignButton(int value, IconData icon) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () { _recordHistory(); setState(() => _alignment = value); },
        isSelected: _alignment == value,
        icon: Icon(icon, size: 17),
        color: Colors.white60,
        selectedIcon: Icon(icon, size: 17, color: const Color(0xFFFFA071)),
      );

  Widget _miniToggle(String label, bool value, ValueChanged<bool> change) =>
      Container(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFFF713B).withValues(alpha: .13) : Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: value ? const Color(0xFFFF8B56).withValues(alpha: .55) : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(width: 3),
            Switch.adaptive(
              value: value,
              onChanged: change,
              activeColor: const Color(0xFFFF8B56),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );

  Widget _miniChoice(String label, int value) => Expanded(
        child: GestureDetector(
          onTap: () { _recordHistory(); setState(() => _textBackground = value); },
          child: Container(
            margin: const EdgeInsetsDirectional.only(end: 5),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: _textBackground == value
                  ? const Color(0xFFFF713B).withValues(alpha: .22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _textBackground == value
                    ? const Color(0xFFFF8B56)
                    : Colors.white12,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textBackground == value
                    ? const Color(0xFFFFA071)
                    : Colors.white70,
                fontSize: 8,
              ),
            ),
          ),
        ),
      );

  Widget _sliderRow(String label, double value, double min, double max,
          ValueChanged<double> change, {VoidCallback? onStart}) =>
      Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 9)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChangeStart: (_) => onStart?.call(),
              onChanged: change,
            ),
          ),
          Text(
            value.round().toString(),
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      );

  Widget _exportBar() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _saveProject(),
            icon: const Icon(Icons.save_rounded, size: 15),
            label: const Text('پروژه', style: TextStyle(fontSize: 10)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 11)),
          )),
          const SizedBox(width: 6),
          Expanded(child: OutlinedButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share_rounded, size: 15),
            label: const Text('ارسال', style: TextStyle(fontSize: 10)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 11)),
          )),
          const SizedBox(width: 6),
          Expanded(child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 16),
            label: Text(_busy ? 'در حال ذخیره' : 'دانلود', style: const TextStyle(fontSize: 10)),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF713B), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 11)),
          )),
        ]),
      );

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202330),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.auto_awesome, color: Colors.white),
                title: Text(
                  'استودیوی رسایار',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'ویرایشگر استوری و تایپوگرافی',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.save_rounded, color: Colors.white),
                title: const Text('ذخیره پروژه برای ادامه ویرایش', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _saveProject(); },
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: Colors.white),
                title: const Text(
                  'ذخیره تصویر',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _save();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreeDIcon extends StatelessWidget {
  const _ThreeDIcon({required this.icon, required this.active});
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? const [Color(0xFFFFB17F), Color(0xFFE84E1B)]
                : const [Color(0xFF62697D), Color(0xFF292D3B)],
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: (active ? const Color(0xFFFF713B) : Colors.black)
                  .withValues(alpha: .38),
              blurRadius: 9,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 3,
              left: 4,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: .28),
                size: 18,
              ),
            ),
            Center(child: Icon(icon, color: Colors.white, size: 18)),
          ],
        ),
      );
}

class _FloatingGlyph extends StatelessWidget {
  const _FloatingGlyph({
    required this.controller,
    required this.icon,
    required this.size,
    this.reverse = false,
  });

  final AnimationController controller;
  final IconData icon;
  final double size;
  final bool reverse;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final phase = reverse ? 1 - controller.value : controller.value;
          final dy = 7 * (0.5 - (phase - .5).abs()) * 2;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: (phase - .5) * .18,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: .22),
                size: size,
                shadows: const [
                  Shadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
            ),
          );
        },
      );
}

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double saturation, double value) onChanged;

  void _update(Offset local, Size size) {
    final sat = (local.dx / size.width).clamp(0.0, 1.0);
    final val = (1 - local.dy / size.height).clamp(0.0, 1.0);
    onChanged(sat, val);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapDown: (details) => _update(details.localPosition, size),
            onPanDown: (details) => _update(details.localPosition, size),
            onPanUpdate: (details) => _update(details.localPosition, size),
            child: CustomPaint(
              painter: _SaturationValuePainter(hue: hue, saturation: saturation, value: value),
              child: const SizedBox.expand(),
            ),
          );
        },
      );
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({required this.hue, required this.saturation, required this.value});
  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pureHue = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(rect, Paint()..color = pureHue);
    final saturationPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Color(0x00FFFFFF)],
      ).createShader(rect);
    canvas.drawRect(rect, saturationPaint);
    final valuePaint = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black]).createShader(rect);
    canvas.drawRect(rect, valuePaint);
    final point = Offset(saturation * size.width, (1 - value) * size.height);
    canvas.drawCircle(point, 10, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(point, 8, Paint()..color = Colors.black.withValues(alpha: .28)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) => hue != oldDelegate.hue || saturation != oldDelegate.saturation || value != oldDelegate.value;
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 44);
    final shift = (phase * 2 * 3.14159);
    paint.color = const Color(0xFFFF713B).withValues(alpha: .10);
    canvas.drawCircle(
      Offset(size.width * (.13 + .035 * _sin(shift)),
          size.height * (.20 + .025 * _cos(shift))),
      88,
      paint,
    );
    paint.color = const Color(0xFF735BFF).withValues(alpha: .11);
    canvas.drawCircle(
      Offset(size.width * (.88 + .03 * _cos(shift)),
          size.height * (.58 + .04 * _sin(shift))),
      110,
      paint,
    );
    paint.color = const Color(0xFF16BFA3).withValues(alpha: .06);
    canvas.drawCircle(
      Offset(size.width * .48, size.height * (.88 + .025 * _sin(shift))),
      74,
      paint,
    );
  }

  double _sin(double v) => _Trig.sin(v);
  double _cos(double v) => _Trig.cos(v);

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _Trig {
  static double sin(double v) {
    // Keep this helper local to avoid any dependency for the ambient painter.
    return _sinApprox(v);
  }

  static double cos(double v) => _sinApprox(v + 1.57079632679);

  static double _sinApprox(double x) {
    final twoPi = 6.28318530718;
    x = x % twoPi;
    if (x > 3.14159265359) x -= twoPi;
    final x2 = x * x;
    return x * (1 - x2 / 6 + x2 * x2 / 120);
  }
}