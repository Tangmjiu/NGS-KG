import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../screens/playlist_category_screen.dart';
import '../screens/search_screen.dart';
import '../screens/rank_detail_screen.dart';
import '../screens/artist_list_screen.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/comments_screen.dart';
import '../screens/fm_screen.dart';
import '../screens/lyrics_screen.dart';
import '../screens/local_music_screen.dart';
import '../screens/player_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/videos_screen.dart';
import '../screens/cloud_disk_screen.dart';
import '../screens/sheet_collection_screen.dart';
import '../screens/sheet_collection_detail_screen.dart';
import '../screens/artist_followed_news_screen.dart';
import '../screens/album_detail_screen.dart';
import '../screens/mv_player_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String playlistDetail = '/playlist/detail';
  static const String playlistCategory = '/playlist/category';
  static const String search = '/search';
  static const String rankDetail = '/rank/detail';
  static const String artistList = '/artist/list';
  static const String artistDetail = '/artist/detail';
  static const String comments = '/comments';
  static const String fm = '/fm';
  static const String lyrics = '/lyrics';
  static const String localMusic = '/local/music';
  static const String player = '/player';
  static const String history = '/history';
  static const String cloud = '/cloud';
  static const String settings = '/settings';
  static const String userProfile = '/user/profile';
  static const String messages = '/messages';
  static const String favoriteVideos = '/videos/favorite';
  static const String likedVideos = '/videos/liked';
  static const String artistFollowedNews = '/artist/followed/news';
  static const String albumDetail = '/album/detail';
  static const String mv = '/mv';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case playlistDetail:
        final args = settings.arguments as Map<String, dynamic>;
        final rawId = args['id'];
        final int? playlistId = rawId is int ? rawId : (rawId is String ? int.tryParse(rawId) : null);
        final String? gcId = args['gcId'] as String? ?? (rawId is String && rawId.contains('_') ? rawId : null);
        return MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(
            playlistId: playlistId,
            gcId: gcId,
            playlistName: args['name'] as String?,
          ),
        );
      case playlistCategory:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PlaylistCategoryScreen(
            categoryId: args['id'] as int,
            categoryName: args['name'] as String,
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
      case AppRoutes.cloud:
        return MaterialPageRoute(builder: (_) => const CloudDiskScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.userProfile:
        return MaterialPageRoute(builder: (_) => const UserProfileScreen());
      case AppRoutes.messages:
        return MaterialPageRoute(builder: (_) => const MessagesScreen());
      case AppRoutes.favoriteVideos:
        return MaterialPageRoute(builder: (_) => const VideosScreen());
      case AppRoutes.likedVideos:
        return MaterialPageRoute(builder: (_) => const VideosScreen(showLiked: true));
      case artistFollowedNews:
        return MaterialPageRoute(builder: (_) => const ArtistFollowedNewsScreen());
      case albumDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AlbumDetailScreen(
            albumId: args['id'] as int,
            albumName: args['name'] as String?,
          ),
        );
      case mv:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MvPlayerScreen(
            hash: args['hash'] as String?,
            name: args['name'] as String?,
          ),
        );
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
