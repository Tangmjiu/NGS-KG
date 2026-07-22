import { MethodChannel, MethodCall, MethodResult, FlutterEngine } from '@ohos/flutter_ohos';
import { deviceInfo } from '@kit.BasicServicesKit';

export class DevicePlugin {
  static register(flutterEngine: FlutterEngine): void {
    const channel: MethodChannel = new MethodChannel(
      flutterEngine.dartExecutor,
      'com.mjiutang.ngskg/device'
    );

    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'getAbi') {
          const abi: string = DevicePlugin.getDeviceAbi();
          result.success(abi);
        } else {
          result.notImplemented();
        }
      }
    });
  }

  private static getDeviceAbi(): string {
    const abiList: string = deviceInfo.abiList;
    return abiList;
  }
}
