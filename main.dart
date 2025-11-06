import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_size_text/auto_size_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LineMonitoringApp());
}

class LineMonitoringApp extends StatelessWidget {
  const LineMonitoringApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Line Monitoring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: const HomeScreen(),
    );
  }
}

class MachineConfig {
  String name;
  String path;
  MachineConfig({this.name = '', this.path = ''});

  Map<String, dynamic> toJson() => {'name': name, 'path': path};
  factory MachineConfig.fromJson(Map<String, dynamic> j) =>
      MachineConfig(name: j['name'] ?? '', path: j['path'] ?? '');
}

class AppConfig {
  List<MachineConfig> machines;
  AppConfig({required this.machines});

  Map<String, dynamic> toJson() => {
    'machines': machines.map((m) => m.toJson()).toList(),
  };

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final list =
        (j['machines'] as List<dynamic>?) ??
        List.generate(8, (_) => {'name': '', 'path': ''});
    return AppConfig(
      machines: list
          .map((e) => MachineConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late AppConfig _config;
  final List<TextEditingController> _nameControllers = List.generate(
    8,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _pathControllers = List.generate(
    8,
    (_) => TextEditingController(),
  );

  final List<int> _errors = List.filled(8, 0);
  final List<AnimationController?> _blinkControllers = List.filled(8, null);

  Timer? _refreshTimer;

  // Menu auto-hide
  bool _isMenuVisible = true;
  bool _isHoveringMenuArea = false;
  Timer? _hideMenuTimer;
  static const double _compactWidth = double.infinity;

  final double tileRadius = 16.0;

  @override
  void initState() {
    super.initState();
    _config = AppConfig(machines: List.generate(8, (_) => MachineConfig()));
    _loadConfig().then((_) {
      _initControllersFromConfig();
      _setupBlinkControllers();
      _startRefreshing();
    });
  }

  void _initControllersFromConfig() {
    for (int i = 0; i < 8; i++) {
      _nameControllers[i].text = _config.machines[i].name;
      _pathControllers[i].text = _config.machines[i].path;
      _nameControllers[i].removeListener(_makeNameListener(i));
      _nameControllers[i].addListener(_makeNameListener(i));
      _pathControllers[i].removeListener(_makePathListener(i));
      _pathControllers[i].addListener(_makePathListener(i));
    }
  }

  VoidCallback _makeNameListener(int idx) {
    return () {
      final v = _nameControllers[idx].text;
      if (_config.machines[idx].name != v) {
        _config.machines[idx].name = v;
      }
    };
  }

  VoidCallback _makePathListener(int idx) {
    return () {
      final v = _pathControllers[idx].text;
      if (_config.machines[idx].path != v) {
        _config.machines[idx].path = v;
      }
    };
  }

  void _setupBlinkControllers() {
    for (int i = 0; i < 8; i++) {
      _blinkControllers[i]?.dispose();
      _blinkControllers[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..addListener(() {});
    }
  }

  void _startRefreshing() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _refreshAllFiles();
    });
  }

  Future<void> _refreshAllFiles() async {
    bool anyChange = false;
    for (int i = 0; i < 8; i++) {
      final path = _config.machines[i].path;
      int value = 0;
      if (path.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) {
            final content = await f.readAsString();
            final firstLine = content.split(RegExp(r'\r?\n'))[0].trim();
            value = int.tryParse(firstLine) ?? 0;
          }
        } catch (e) {
          value = 0;
        }
      }
      if (_errors[i] != value) {
        _errors[i] = value;
        anyChange = true;
      }
      final controller = _blinkControllers[i];
      if (controller != null) {
        final dur = _blinkDurationForValue(value);
        if (dur == Duration.zero) {
          if (controller.isAnimating) controller.stop();
          controller.value = 1.0;
        } else {
          if (controller.duration != dur) controller.duration = dur;
          if (!controller.isAnimating) controller.repeat(reverse: true);
        }
      }
    }
    if (anyChange && mounted) setState(() {});
  }

  Duration _blinkDurationForValue(int value) {
    if (value >= 5) return const Duration(milliseconds: 900);
    if (value >= 3) return const Duration(milliseconds: 1500);
    return Duration.zero;
  }

  Color _baseColorForValue(int value) {
    if (value >= 5) return Colors.red;
    if (value >= 3) return Colors.amber.shade700;
    return Colors.white;
  }

  Color _textColorForValue(int value) {
    if (value <= 2) return Colors.black87;
    return Colors.white;
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('app_config');
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        setState(() {
          _config = AppConfig.fromJson(decoded);
        });
      } else {
        setState(() {
          _config = AppConfig(
            machines: List.generate(8, (_) => MachineConfig()),
          );
        });
      }
    } catch (e) {
      setState(() {
        _config = AppConfig(machines: List.generate(8, (_) => MachineConfig()));
      });
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_config.toJson());
    await prefs.setString('app_config', jsonStr);
    for (int i = 0; i < 8; i++) {
      _nameControllers[i].text = _config.machines[i].name;
      _pathControllers[i].text = _config.machines[i].path;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ÄÃ£ lÆ°u cáº¥u hÃ¬nh')));
    }
  }

  Future<void> _resetConfig() async {
    setState(() {
      _config = AppConfig(machines: List.generate(8, (_) => MachineConfig()));
      for (int i = 0; i < 8; i++) {
        _nameControllers[i].text = '';
        _pathControllers[i].text = '';
        _errors[i] = 0;
      }
    });
    await _saveConfig();
  }

  void _onMenuAreaEnter() {
    _isHoveringMenuArea = true;
    _hideMenuTimer?.cancel();
    if (!_isMenuVisible) {
      setState(() {
        _isMenuVisible = true;
      });
    }
  }

  void _onMenuAreaExit() {
    _isHoveringMenuArea = false;
    _startHideMenuTimer();
  }

  void _startHideMenuTimer() {
    _hideMenuTimer?.cancel();
    _hideMenuTimer = Timer(const Duration(milliseconds: 600), () {
      if (!_isHoveringMenuArea && mounted) {
        setState(() {
          _isMenuVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _hideMenuTimer?.cancel();
    for (final c in _blinkControllers) {
      c?.dispose();
    }
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _pathControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _menuBar(bool isCompact) {
    return Row(
      children: [
        _menuButton('GiÃ¡m sÃ¡t', 0, isCompact),
        const SizedBox(width: 8),
        _menuButton('Cáº¥u hÃ¬nh', 1, isCompact),
      ],
    );
  }

  Widget _menuButton(String text, int idx, bool isCompact) {
    final selected = _selectedIndex == idx;

    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = idx);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _configTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Padding(padding: EdgeInsetsGeometry.all(20)),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  await _resetConfig();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ÄÃ£ reset cáº¥u hÃ¬nh')),
                  );
                },
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _saveConfig();
                },
                child: const Text('Save'),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chá»n file .txt chá»©a 1 sá»‘ nguyÃªn á»Ÿ dÃ²ng 1'),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('HÆ°á»›ng dáº«n'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 8; i++) _configRow(i),
        ],
      ),
    );
  }

  Widget _configRow(int idx) {
    final mc = _config.machines[idx];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                'MÃ¡y ${idx + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _nameControllers[idx],
                decoration: const InputDecoration(
                  labelText: 'TÃªn mÃ¡y',
                  isDense: true,
                ),
                onSubmitted: (_) => _saveConfig(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _pathControllers[idx],
                decoration: const InputDecoration(
                  labelText: 'ÄÆ°á»ng dáº«n file lá»—i (txt)',
                  isDense: true,
                ),
                onSubmitted: (_) => _saveConfig(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty) {
                  final p = result.files.single.path;
                  if (p != null) {
                    setState(() {
                      mc.path = p;
                      _pathControllers[idx].text = p;
                    });
                    await _saveConfig();
                  }
                }
              },
              child: const Text('Browse'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'XÃ³a tÃªn',
              onPressed: () {
                setState(() {
                  _nameControllers[idx].text = '';
                  mc.name = '';
                });
              },
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monitorTab() {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(4, (i) {
                return Expanded(child: _monitorTile(i));
              }),
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: List.generate(4, (i) {
                return Expanded(child: _monitorTile(i + 4));
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monitorTile(int idx) {
    final name = _config.machines[idx].name.isEmpty
        ? 'MÃ¡y ${idx + 1}'
        : _config.machines[idx].name;
    final val = _errors[idx];
    final controller = _blinkControllers[idx];

    final base = _baseColorForValue(val);
    final txtColor = _textColorForValue(val);

    Widget tileContent() {
      return Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(tileRadius),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;

            final nameFontSize = (maxHeight * 0.18)
                .clamp(10.0, 28.0)
                .roundToDouble();

            final valueFontSize = (maxHeight * 0.5)
                .clamp(20.0, 200.0)
                .roundToDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: maxHeight * 0.2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        name,
                        style: TextStyle(
                          color: txtColor,
                          fontWeight: FontWeight.bold,
                          fontSize: nameFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        val.toString(),
                        style: TextStyle(
                          color: txtColor,
                          fontWeight: FontWeight.bold,
                          fontSize: valueFontSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    if (controller != null && controller.isAnimating && val >= 3) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final opacity = 0.45 + 0.55 * controller.value;
          return Opacity(opacity: opacity, child: tileContent());
        },
      );
    } else {
      return tileContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactWidth;

        // Tá»± Ä‘á»™ng áº©n menu khi chuyá»ƒn sang compact mode
        if (isCompact && _isMenuVisible && !_isHoveringMenuArea) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startHideMenuTimer();
          });
        }

        // Tá»± Ä‘á»™ng hiá»‡n menu khi chuyá»ƒn vá» normal mode
        if (!isCompact && !_isMenuVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isMenuVisible = true;
            });
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // Main content - chiáº¿m toÃ n bá»™ khÃ´ng gian
              SafeArea(
                minimum: const EdgeInsets.all(8),
                child: _selectedIndex == 0 ? _monitorTab() : _configTab(),
              ),

              // Floating menu - trÆ°á»£t tá»« trÃªn xuá»‘ng
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MouseRegion(
                  onEnter: (_) {
                    if (isCompact) _onMenuAreaEnter();
                  },
                  onExit: (_) {
                    if (isCompact) _onMenuAreaExit();
                  },
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: (isCompact && !_isMenuVisible)
                        ? const Offset(0, -1.0) // áº¨n hoÃ n toÃ n lÃªn trÃªn
                        : Offset.zero, // Hiá»‡n Ä‘áº§y Ä‘á»§
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        boxShadow: _isMenuVisible
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: _menuBar(isCompact),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // VÃ¹ng trigger nhá» á»Ÿ trÃªn cÃ¹ng Ä‘á»ƒ kÃ­ch hoáº¡t menu khi áº©n
              if (isCompact && !_isMenuVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: MouseRegion(
                    onEnter: (_) => _onMenuAreaEnter(),
                    child: Container(height: 8, color: Colors.transparent),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}