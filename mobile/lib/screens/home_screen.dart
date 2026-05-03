import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/playlist_card.dart';
import '../widgets/player_bar.dart';
import 'login_screen.dart';
import 'search_screen.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('NGS-KG+'),
        actions: [
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
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerBar(),
          BottomNavigationBar(
            currentIndex: 0,
            items: [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.explore), label: '发现'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<PlaylistProvider>(
      builder: (_, provider, __) {
        if (provider.isLoading) {
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
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
