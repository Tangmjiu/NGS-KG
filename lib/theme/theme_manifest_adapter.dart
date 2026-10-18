// SPDX-License-Identifier: MIT
/// 将历史 ZIP 清单及磁盘记录归一为当前主题模型的字段。
abstract final class ThemeManifestAdapter {
  static Map<String, dynamic> map(Object? value) => value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value))
      : <String, dynamic>{};

  static Map<String, dynamic> normalize(Map<String, dynamic> source) {
    final colors = map(source['colors']);
    final typography = map(source['typography']);
    final wallpaper = map(source['wallpaper']);
    final shapes = map(source['shapes']);
    final components = map(source['components']);
    final design = <String, dynamic>{
      if (shapes['lg'] != null) 'cardRadius': shapes['lg'],
      if (shapes['md'] != null) 'controlRadius': shapes['md'],
      ...map(source['tokens']),
      ...map(source['design']),
    };
    return {
      ...source,
      'lightScheme': source['lightScheme'] ?? colors['light'],
      'darkScheme': source['darkScheme'] ?? colors['dark'],
      'fontFamily': source['fontFamily'] ?? typography['family'],
      'fontWeightFiles': source['fontWeightFiles'] ?? typography['weight'],
      'assetFiles': source['assetFiles'] ?? source['assets'],
      'playerBgPath': source['playerBgPath'] ?? wallpaper['player'],
      'lyricSettingsOverride':
          source['lyricSettingsOverride'] ?? source['lyricSettings'],
      'design': design,
      'components': {
        'navigationBarElevation': components['navigationBarElevation'] ??
            map(components['navigationBar'])['elevation'],
        'cardElevation':
            components['cardElevation'] ?? map(components['card'])['elevation'],
        'dialogElevation': components['dialogElevation'] ??
            map(components['dialog'])['elevation'],
      },
    };
  }
}
