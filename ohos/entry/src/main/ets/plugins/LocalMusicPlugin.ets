import { MethodChannel, MethodCall, MethodResult, FlutterEngine } from '@ohos/flutter_ohos';

export class LocalMusicPlugin {
  static register(flutterEngine: FlutterEngine): void {
    const channel: MethodChannel = new MethodChannel(
      flutterEngine.dartExecutor,
      'com.mjiutang.ngskg/local_music'
    );

    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'scanMusic') {
          result.success([]);
        } else {
          result.notImplemented();
        }
      }
    });
  }
}
