import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/rank_detail_screen.dart';
import '../screens/artist_list_screen.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/comments_screen.dart';
import '../screens/sheet_list_screen.dart';
import '../screens/sheet_detail_screen.dart';
import '../screens/fm_screen.dart';
import '../screens/lyrics_screen.dart';
import '../screens/local_music_screen.dart';
import '../screens/player_screen.dart';
import '../screens/history_screen.dart';
import '../screens/cloud_disk_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String playlistDetail = '/playlist/detail';
  static const String search = '/search';
  static const String rankDetail = '/rank/detail';
  static const String artistList = '/artist/list';
  static const String artistDetail = '/artist/detail';
  static const String comments = '/comments';
  static const String sheetList = '/sheet/list';
  static const String sheetDetail = '/sheet/detail';
  static const String fm = '/fm';
  static const String lyrics = '/lyrics';
  static const String localMusic = '/local/music';
  static const String player = '/player';
  static const String history = '/history';
  static const String cloud = '/cloud';

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
            playlistId: args['id'] as int?,
            gcId: args['gcId'] as String?,
            playlistName: args['name'] as String?,
          ),
        );
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case rankDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RankDetailScreen(
            rankId: args['id'] as int,
            rankName: args['name'] as String?,
          ),
        );
      case artistList:
        return MaterialPageRoute(builder: (_) => const ArtistListScreen());
      case artistDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ArtistDetailScreen(
            artistId: args['id'] as int,
            artistName: args['name'] as String?,
          ),
        );
      case comments:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CommentsScreen(
            type: args['type'] as String? ?? 'music',
            id: args['id'] as int,
          ),
        );
      case sheetList:
        return MaterialPageRoute(builder: (_) => const SheetListScreen());
      case sheetDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => SheetDetailScreen(
            sheetId: args['id'] as int? ?? 0,
            sheetName: args['name'] as String?,
          ),
        );
      case fm:
        return MaterialPageRoute(builder: (_) => const FmScreen());
      case lyrics:
        return MaterialPageRoute(builder: (_) => const LyricsScreen());
      case localMusic:
        return MaterialPageRoute(builder: (_) => const LocalMusicScreen());
      case player:
        return MaterialPageRoute(builder: (_) => const PlayerScreen());
      case history:
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      case cloud:
        return MaterialPageRoute(builder: (_) => const CloudDiskScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
