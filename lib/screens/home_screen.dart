import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/playlist_card.dart';
import '../widgets/tablet_scaffold.dart';
import '../utils/responsive.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().fetchTopPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTabletLand = Responsive.isTabletLandscape(context);

    if (isTabletLand) {
      return TabletScaffold(
        currentIndex: _currentTab,
        onTabChanged: (i) => setState(() => _currentTab = i),
        tabs: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
        pages: [
          _buildPage(AppBar(
            title: const Text('NGS-KG+'),
            actions: _appBarActions(context),
          ), _buildHome()),
          _buildPage(null, const DiscoverScreen()),
          _buildPage(null, const ProfileScreen()),
        ],
      );
    }

    return Scaffold(
      appBar: _currentTab == 0
          ? AppBar(
              title: const Text('NGS-KG+'),
              actions: _appBarActions(context),
            )
          : null,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHome(),
          const DiscoverScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  List<Widget> _appBarActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => Navigator.pushNamed(context, '/search'),
      ),
      Consumer<AuthProvider>(
        builder: (_, auth, __) => IconButton(
          icon: Icon(auth.isLoggedIn ? Icons.person : Icons.person_outline),
          onPressed: () {
            if (!auth.isLoggedIn) {
              Navigator.pushNamed(context, '/login');
            }
          },
        ),
      ),
    ];
  }

  Widget _buildPage(AppBar? appBar, Widget body) {
    if (appBar == null) return body;
    return Column(
      children: [
        appBar,
        Expanded(child: body),
      ],
    );
  }

  Widget _buildHome() {
    return Consumer<PlaylistProvider>(
      builder: (_, provider, __) {
        if (provider.isLoading && provider.topPlaylists.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () => provider.fetchTopPlaylists(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.topPlaylists.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('推荐歌单',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                );
              }
              final pl = provider.topPlaylists[i - 1];
              return PlaylistCard(playlist: pl);
            },
          ),
        );
      },
    );
  }
}
