import 'package:flutter/material.dart';
import 'about_page.dart';
import 'lookup_page.dart';
import 'verify_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final List<_ToolEntry> _entries = const [
    _ToolEntry(
      title: '信息查询',
      icon: Icons.search,
      color: Color(0xFF6C63FF),
      cards: [
        _ToolCard(
          title: '信息查询',
          subtitle: 'QQ / 手机号 / 证件号 / 邮箱 / 微博UID',
          icon: Icons.privacy_tip,
          route: LookupPage(),
        ),
      ],
    ),
    _ToolEntry(
      title: '核验',
      icon: Icons.verified_user,
      color: Color(0xFF0288D1),
      cards: [
        _ToolCard(
          title: '二要素核验',
          subtitle: '姓名 + 身份证号验证',
          icon: Icons.fingerprint,
          route: VerifyPage(),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _index,
        children: _entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          return _ToolScaffold(
            title: e.title,
            color: e.color,
            icon: e.icon,
            cards: e.cards,
            onAbout: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
            onCardTap: (card, page) {
              if (i == _index) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => page),
                );
              }
            },
          );
        }).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _entries
            .map((e) => NavigationDestination(
                  icon: Icon(e.icon),
                  selectedIcon: Icon(e.icon),
                  label: e.title,
                ))
            .toList(),
      ),
    );
  }
}

class _ToolScaffold extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<_ToolCard> cards;
  final VoidCallback onAbout;
  final Function(_ToolCard, Widget) onCardTap;

  const _ToolScaffold({
    required this.title,
    required this.color,
    required this.icon,
    required this.cards,
    required this.onAbout,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于',
            onPressed: onAbout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: cards
            .map((card) => _buildCard(context, card))
            .toList(),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _ToolCard card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onCardTap(card, card.route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: card.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    card.icon,
                    size: 28,
                    color: card.color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget route;

  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = const Color(0xFF6C63FF),
    required this.route,
  });
}

class _ToolEntry {
  final String title;
  final IconData icon;
  final Color color;
  final List<_ToolCard> cards;

  const _ToolEntry({
    required this.title,
    required this.icon,
    required this.color,
    required this.cards,
  });
}