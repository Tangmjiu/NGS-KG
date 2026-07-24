import { MethodChannel, MethodCall, MethodResult, FlutterEngine } from '@ohos/flutter_ohos';

export class EqualizerPlugin {
  static register(flutterEngine: FlutterEngine): void {
    const channel: MethodChannel = new MethodChannel(
      flutterEngine.dartExecutor,
      'com.mjiutang.ngskg/equalizer'
    );

    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        const method: string = call.method;

        if (method === 'getBandLevelRange') {
          result.success([0, 0]);
        } else if (method === 'getNumberOfBands') {
          result.success(5);
        } else if (method === 'getCenterFreq') {
          result.success(0);
        } else if (method === 'setBandLevel') {
          result.success(null);
        } else if (method === 'getBandLevel') {
          result.success(0);
        } else if (method === 'release') {
          result.success(null);
        } else {
          result.notImplemented();
        }
      }
    });
  }
}
