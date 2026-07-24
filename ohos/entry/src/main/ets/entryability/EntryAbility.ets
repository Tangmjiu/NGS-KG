import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { MetadataPlugin } from '../plugins/MetadataPlugin';
import { EqualizerPlugin } from '../plugins/EqualizerPlugin';
import { LocalMusicPlugin } from '../plugins/LocalMusicPlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    MetadataPlugin.register(flutterEngine);
    EqualizerPlugin.register(flutterEngine);
    LocalMusicPlugin.register(flutterEngine);
  }
}
