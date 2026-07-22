import { MethodChannel, MethodCall, MethodResult, FlutterEngine } from '@ohos/flutter_ohos';

export class MetadataPlugin {
  static register(flutterEngine: FlutterEngine): void {
    const channel: MethodChannel = new MethodChannel(
      flutterEngine.dartExecutor,
      'com.mjiutang.ngskg/metadata'
    );

    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'read') {
          result.success(null);
        } else {
          result.notImplemented();
        }
      }
    });
  }
}
