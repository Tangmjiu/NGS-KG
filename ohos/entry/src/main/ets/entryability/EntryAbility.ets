import { FlutterAbility, FlutterEngine, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { MediaSessionPlugin } from '../plugins/MediaSessionPlugin';
import { DevicePlugin } from '../plugins/DevicePlugin';
import { MetadataPlugin } from '../plugins/MetadataPlugin';
import { EqualizerPlugin } from '../plugins/EqualizerPlugin';
import { SqflitePlugin } from '../plugins/SqflitePlugin';
import { LocalMusicPlugin } from '../plugins/LocalMusicPlugin';
import { NotificationPlugin } from '../plugins/NotificationPlugin';

export default class EntryAbility extends FlutterAbility {
  private mediaSessionPlugin: MediaSessionPlugin | undefined = undefined;

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    this.mediaSessionPlugin = MediaSessionPlugin.create(
      flutterEngine,
      () => { },
      () => { },
      () => { },
      () => { },
      () => { },
      (posMs: number): void => { }
    );

    DevicePlugin.register(flutterEngine);
    MetadataPlugin.register(flutterEngine);
    EqualizerPlugin.register(flutterEngine);
    SqflitePlugin.register(flutterEngine);
    LocalMusicPlugin.register(flutterEngine);
    NotificationPlugin.register(flutterEngine);
  }

  onForeground(): void {
    super.onForeground();
    if (this.mediaSessionPlugin !== undefined) {
      this.mediaSessionPlugin.createSession(this.context);
    }
  }

  onBackground(): void {
    super.onBackground();
  }

  onDestroy(): void {
    if (this.mediaSessionPlugin !== undefined) {
      this.mediaSessionPlugin.release();
    }
    super.onDestroy();
  }
}
