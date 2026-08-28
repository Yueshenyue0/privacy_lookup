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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _ToolScaffold(
            title: '信息查询',
            child: _ToolTabScaffold(tabs: [
              Tab(text: '信息查询'),
            ], pages: [LookupPage()]),
          ),
          _ToolScaffold(
            title: '核验',
            child: _ToolTabScaffold(tabs: [
              Tab(text: '二要素核验'),
            ], pages: [VerifyPage()]),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: '信息查询',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            selectedIcon: Icon(Icons.verified_user),
            label: '核验',
          ),
        ],
      ),
    );
  }
}

/// 每个工具入口的壳：AppBar（含右上角"关于"）+ 内容
class _ToolScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _ToolScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
        ],
      ),
      body: child,
    );
  }
}

/// 每个入口内的功能 Tab 容器
class _ToolTabScaffold extends StatelessWidget {
  final List<Tab> tabs;
  final List<Widget> pages;

  const _ToolTabScaffold({required this.tabs, required this.pages});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: tabs,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}