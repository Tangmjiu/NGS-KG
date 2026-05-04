import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/rank_detail_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String playlistDetail = '/playlist/detail';
  static const String search = '/search';
  static const String rankDetail = '/rank/detail';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case playlistDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(
            playlistId: args['id'] as int,
            playlistName: args['name'] as String?,
          ),
        );
      case rankDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RankDetailScreen(
            rankId: args['id'] as int,
            rankName: args['name'] as String?,
          ),
        );
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
