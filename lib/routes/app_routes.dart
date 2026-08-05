import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/rank_detail_screen.dart';
import '../screens/artist_list_screen.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/comments_screen.dart';
import '../screens/fm_screen.dart';
import '../screens/local_music_screen.dart';
import '../screens/player_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/messages_screen.dart';
// MV: import '../screens/videos_screen.dart';
import '../screens/cloud_disk_screen.dart';
import '../screens/artist_followed_news_screen.dart';
import '../screens/album_detail_screen.dart';
// MV: import '../screens/mv_player_screen.dart';
import '../screens/recommended_playlists_screen.dart';
import '../screens/playlist_category_screen.dart';
import '../screens/api_settings_screen.dart';
import '../screens/theme_settings_screen.dart';
import '../screens/theme_market_screen.dart';
import '../screens/audio_effects_screen.dart';
import '../screens/about_screen.dart';
import '../screens/log_viewer_screen.dart';
import '../screens/lyric_settings_screen.dart';
import '../screens/profile_screen.dart' show LikedSongsScreen;
import '../screens/download_screen.dart';
import '../navidrome/navidrome_login_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String playlistDetail = '/playlist/detail';
  static const String search = '/search';
  static const String rankDetail = '/rank/detail';
  static const String artistList = '/artist/list';
  static const String artistDetail = '/artist/detail';
  static const String comments = '/comments';
  static const String fm = '/fm';
  static const String localMusic = '/local/music';
  static const String player = '/player';
  static const String history = '/history';
  static const String cloud = '/cloud';
  static const String settings = '/settings';
  static const String userProfile = '/user/profile';
  static const String messages = '/messages';
  // MV: static const String favoriteVideos = '/videos/favorite';
  // MV: static const String likedVideos = '/videos/liked';
  static const String artistFollowedNews = '/artist/followed/news';
  static const String albumDetail = '/album/detail';
  // MV: static const String mv = '/mv';
  static const String recommendedPlaylists = '/recommended/playlists';
  static const String playlistCategory = '/playlist/category';
  static const String apiSettings = '/settings/api';
  static const String themeSettings = '/settings/theme';
  static const String themeMarket = '/settings/theme/market';
  static const String audioEffects = '/settings/audio/effects';
  static const String about = '/about';
  static const String logViewer = '/settings/developer/log';
  static const String lyricSettings = '/settings/lyric';
  static const String likedSongs = '/liked/songs';
  static const String downloads = '/downloads';
  static const String navidromeLogin = '/navidrome/login';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const HomeScreen());
      case login:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const LoginScreen());
      case playlistDetail:
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) return _fallback();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PlaylistDetailScreen(
            gcId: args['gcId'] as String?,
            playlistName: args['name'] as String?,
          ),
        );
      case search:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SearchScreen(),
        );
      case rankDetail:
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) return _fallback();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RankDetailScreen(
            rankId: args['id'] as int,
            rankName: args['name'] as String?,
          ),
        );
      case artistList:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const ArtistListScreen());
      case artistDetail:
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) return _fallback();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ArtistDetailScreen(
            artistId: args['id'] as int,
            artistName: args['name'] as String?,
          ),
        );
      case comments:
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) return _fallback();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CommentsScreen(
            type: args['type'] as String? ?? 'music',
            id: args['id'] as int,
            gcId: args['gcId'] as String?,
          ),
        );
      case fm:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const FmScreen());
      case localMusic:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const LocalMusicScreen());
      case player:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const PlayerScreen());
      case history:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const HistoryScreen());
      case AppRoutes.cloud:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const CloudDiskScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const SettingsScreen());
      case AppRoutes.userProfile:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const UserProfileScreen());
      case AppRoutes.messages:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const MessagesScreen());
      // MV: case AppRoutes.favoriteVideos:
      // MV:   return MaterialPageRoute(builder: (_) => const VideosScreen());
      // MV: case AppRoutes.likedVideos:
      // MV:   return MaterialPageRoute(
      // MV:       builder: (_) => const VideosScreen(showLiked: true));
      case artistFollowedNews:
        return MaterialPageRoute(
            settings: settings,
            builder: (_) => const ArtistFollowedNewsScreen());
      case albumDetail:
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) return _fallback();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AlbumDetailScreen(
            albumId: args['id'] as int,
            albumName: args['name'] as String?,
          ),
        );
      // MV: case mv:
      // MV:   final args = settings.arguments;
      // MV:   if (args is! Map<String, dynamic>) return _fallback();
      // MV:   return MaterialPageRoute(
      // MV:     builder: (_) => MvPlayerScreen(
      // MV:       hash: args['hash'] as String?,
      // MV:       name: args['name'] as String?,
      // MV:     ),
      // MV:   );
      case AppRoutes.recommendedPlaylists:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RecommendedPlaylistsScreen(),
        );
      case AppRoutes.playlistCategory:
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) return _fallback();
        final categoryId = args['categoryId'] as int?;
        final categoryName = args['name'] as String?;
        if (categoryId == null || categoryName == null) return _fallback();
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PlaylistCategoryScreen(
            categoryId: categoryId,
            categoryName: categoryName,
          ),
        );
      case AppRoutes.apiSettings:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const ApiSettingsScreen());
      case AppRoutes.themeSettings:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const ThemeSettingsScreen());
      case AppRoutes.themeMarket:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const ThemeMarketScreen());
      case AppRoutes.audioEffects:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const AudioEffectsScreen());
      case AppRoutes.about:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const AboutScreen());
      case AppRoutes.logViewer:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const LogViewerScreen());
      case AppRoutes.lyricSettings:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const LyricSettingsScreen());
      case AppRoutes.likedSongs:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const LikedSongsScreen());
      case AppRoutes.downloads:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const DownloadScreen());
      case AppRoutes.navidromeLogin:
        return MaterialPageRoute(
            settings: settings, builder: (_) => const NavidromeLoginScreen());
      default:
        return _fallback();
    }
  }

  static Route<dynamic> _fallback() {
    return MaterialPageRoute(builder: (_) => const HomeScreen());
  }
}
