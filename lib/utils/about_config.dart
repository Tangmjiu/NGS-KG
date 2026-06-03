/// 关于页面配置（编译时可覆盖）
///
/// 构建时通过 --dart-define 传入自定义值，例如：
///   flutter build apk --dart-define=ABOUT_APP_NAME=MyApp
///
/// 编译后的安装包中这些值不可更改。
class AboutConfig {
  AboutConfig._();

  // ─── 基本信息 ───

  static const String appName =
      String.fromEnvironment('ABOUT_APP_NAME', defaultValue: 'NGS-KG+');

  static const String version =
      String.fromEnvironment('ABOUT_VERSION', defaultValue: '1.0.0+1');

  // ─── 简介 ───

  static const String description = String.fromEnvironment(
    'ABOUT_DESCRIPTION',
    defaultValue: '基于酷狗音乐第三方 API 的 Flutter 音乐播放器，'
        '支持登录、歌单管理、音乐搜索、在线播放、歌词显示、'
        '排行榜、本地音乐播放等功能。',
  );

  // ─── 链接 ───

  static const String githubUrl = String.fromEnvironment(
    'ABOUT_GITHUB_URL',
    defaultValue: 'https://github.com/Tangmjiu/NGS-KG/',
  );

  static const String apiDocUrl = String.fromEnvironment(
    'ABOUT_API_DOC_URL',
    defaultValue: 'https://github.com/MakcRe/KuGouMusicApi',
  );

  static const String changelogUrl = String.fromEnvironment(
    'ABOUT_CHANGELOG_URL',
    defaultValue: 'https://github.com/Tangmjiu/NGS-KG/releases',
  );

  static const String faqUrl = String.fromEnvironment(
    'ABOUT_FAQ_URL',
    defaultValue: 'https://github.com/Tangmjiu/NGS-KG/blob/main/FAQ.md',
  );

  static const String themeUrl = String.fromEnvironment(
    'ABOUT_THEME_URL',
    defaultValue: 'https://github.com/Tangmjiu/NGS-KG/blob/main/THEME.md',
  );

  // ─── 版权（不可被 dart-define 覆盖） ───

  static const String copyright =
      'Copyright © 2004-2026 mjiutang. All Rights Reserved';

  static const String copyrightNotice =
      '请遵循当地法律使用该软件，在线服务协议最终解释权由广州酷狗计算机科技有限公司所有。';
}
