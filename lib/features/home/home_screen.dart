import 'package:flutter/material.dart';
import '../../core/theme/rasayar_theme.dart';
import '../editor/story_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_rounded), label: 'خانه'),
    NavigationDestination(icon: Icon(Icons.folder_copy_rounded), label: 'پروژه‌ها'),
    NavigationDestination(icon: Icon(Icons.add_rounded), label: 'بساز'),
    NavigationDestination(icon: Icon(Icons.auto_awesome_mosaic_rounded), label: 'قالب‌ها'),
    NavigationDestination(icon: Icon(Icons.person_rounded), label: 'من'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(
        onCreate: () => _go(2),
        onOpen: _openStudio,
      ),
      const _EmptyHub(
        icon: Icons.folder_copy_rounded,
        title: 'پروژه‌های من',
        subtitle: 'طرح‌ها و استوری‌های ذخیره‌شده‌ات اینجا جمع می‌شوند.',
        accent: Color(0xFF8D7BFF),
      ),
      StoryEditorScreen(onBack: () => _go(0)),
      const _EmptyHub(
        icon: Icons.auto_awesome_mosaic_rounded,
        title: 'کتابخانه قالب‌ها',
        subtitle: 'قالب‌های استوری، استایل‌های متن و پس‌زمینه‌ها در این بخش قرار می‌گیرند.',
        accent: Color(0xFF2CC9A7),
      ),
      const _EmptyHub(
        icon: Icons.person_rounded,
        title: 'حساب کاربری',
        subtitle: 'تنظیمات و شخصی‌سازی رسایار',
        accent: Color(0xFFFFA15C),
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _selectedIndex == 2
            ? null
            : AppBar(
                titleSpacing: 18,
                title: Row(
                  children: [
                    const _BrandMark(),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رسایار',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'CREATIVE STUDIO',
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'تغییر پوسته',
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
        body: SafeArea(child: IndexedStack(index: _selectedIndex, children: pages)),
        // Keep the editor immersive: the global navigation is available in
        // the other sections, but hidden while the story canvas is active.
        bottomNavigationBar: _selectedIndex == 2
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _go,
                destinations: _destinations,
              ),
      ),
    );
  }

  void _go(int index) => setState(() => _selectedIndex = index);

  void _openStudio(String studio) {
    if (studio == 'متن' || studio == 'استوری' || studio == 'فونت') {
      _go(2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بخش $studio در به‌روزرسانی بعدی فعال می‌شود.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB17F), Color(0xFFE84E1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44FF713B),
              blurRadius: 12,
              offset: Offset(0, 5),
            )
          ],
        ),
        child: const Center(
          child: Text(
            'R',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({required this.onCreate, required this.onOpen});
  final VoidCallback onCreate;
  final ValueChanged<String> onOpen;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Text(
          'ایده‌ات را بساز؛',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          'از یک متن ساده تا یک استوری چشم‌گیر.',
          style: text.bodyMedium?.copyWith(
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 18),
        _CreateHero(
          controller: _float,
          onTap: widget.onCreate,
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            Text(
              'از کجا شروع کنیم؟',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            Text(
              'انتخاب سریع',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: 1.24,
          children: [
            _ToolCard(
              icon: Icons.auto_awesome_mosaic_rounded,
              title: 'استوری آماده',
              subtitle: 'قالب‌های سریع و جذاب',
              color: const Color(0xFFFF804D),
              onTap: () => widget.onOpen('استوری'),
            ),
            _ToolCard(
              icon: Icons.text_fields_rounded,
              title: 'طراحی متن',
              subtitle: 'تایپوگرافی و نوشته',
              color: const Color(0xFF8B7CFF),
              onTap: () => widget.onOpen('متن'),
            ),
            _ToolCard(
              icon: Icons.font_download_rounded,
              title: 'استودیو فونت',
              subtitle: 'سبک و ظاهر نوشته',
              color: const Color(0xFF24BFA1),
              onTap: () => widget.onOpen('فونت'),
            ),
            _ToolCard(
              icon: Icons.movie_filter_rounded,
              title: 'حرکت و افکت',
              subtitle: 'انیمیشن و جلوه بصری',
              color: const Color(0xFF55A7EA),
              onTap: () => widget.onOpen('افکت'),
            ),
          ],
        ),
        const SizedBox(height: 23),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1B1E29) : Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: .5),
            ),
          ),
          child: Row(
            children: [
              const _Mini3DIcon(
                icon: Icons.tips_and_updates_rounded,
                color: Color(0xFFFFB44D),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'یک شروع ساده',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'متنت را بنویس، یک استایل انتخاب کن و خروجی بگیر.',
                      style: TextStyle(fontSize: 11, height: 1.6),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreateHero extends StatelessWidget {
  const _CreateHero({required this.controller, required this.onTap});
  final AnimationController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final lift = 5 * controller.value;
          return GestureDetector(
            onTap: onTap,
            child: Container(
              height: 188,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF965D), Color(0xFFEA5527), Color(0xFFB93C2D)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(27),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44E95720),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  )
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 2 + lift,
                    child: Transform.rotate(
                      angle: -.13,
                      child: _FloatingTile(
                        icon: Icons.text_fields_rounded,
                        size: 68,
                        color: const Color(0xFF8B7CFF),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 62,
                    bottom: 7 - lift,
                    child: Transform.rotate(
                      angle: .10,
                      child: _FloatingTile(
                        icon: Icons.auto_awesome_rounded,
                        size: 53,
                        color: const Color(0xFF25C7A5),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 0,
                    top: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'استودیوی خلاقیت',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 9),
                        Text(
                          'وقتشه ایده‌ات\nرو تبدیل به طرح کنی',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.45,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: FilledButton.tonalIcon(
                      onPressed: onTap,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('شروع طراحی'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE95720),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _FloatingTile extends StatelessWidget {
  const _FloatingTile({
    required this.icon,
    required this.size,
    required this.color,
  });
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: .98), color.withValues(alpha: .68)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * .27),
          border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * .47),
      );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1B1E29) : Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: .5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Mini3DIcon(icon: icon, color: color),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini3DIcon extends StatelessWidget {
  const _Mini3DIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: .95), color.withValues(alpha: .62)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .36)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 3,
              left: 5,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: .35),
                size: 18,
              ),
            ),
            Center(child: Icon(icon, color: Colors.white, size: 22)),
          ],
        ),
      );
}

class _EmptyHub extends StatelessWidget {
  const _EmptyHub({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Mini3DIcon(icon: icon, color: accent),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      );
}
