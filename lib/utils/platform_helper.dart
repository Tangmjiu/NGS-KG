import 'dart:io';

bool get isOhos => Platform.operatingSystem == 'ohos';

bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS || isOhos;
