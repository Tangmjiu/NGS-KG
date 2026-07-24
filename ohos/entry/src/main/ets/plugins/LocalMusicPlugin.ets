import { MethodChannel, MethodCall, MethodResult, FlutterEngine } from '@ohos/flutter_ohos';
import { fileIo } from '@kit.CoreFileKit';

class AudioFileInfo {
  title: string;
  artist: string;
  album: string;
  filePath: string;
  id: number;
  size: number;
  duration: number;

  constructor() {
    this.title = '';
    this.artist = '';
    this.album = '';
    this.filePath = '';
    this.id = 0;
    this.size = 0;
    this.duration = 0;
  }
}

const AUDIO_EXTENSIONS: string[] = ['.mp3', '.flac', '.wav', '.aac', '.ogg', '.wma', '.m4a'];

function isAudioFile(filePath: string): boolean {
  const lower: string = filePath.toLowerCase();
  for (let i: number = 0; i < AUDIO_EXTENSIONS.length; i++) {
    if (lower.endsWith(AUDIO_EXTENSIONS[i])) {
      return true;
    }
  }
  return false;
}

function getFileName(filePath: string): string {
  const parts: string[] = filePath.split('/');
  return parts[parts.length - 1];
}

function getTitleFromFileName(fileName: string): string {
  const dotIdx: number = fileName.lastIndexOf('.');
  if (dotIdx > 0) {
    return fileName.substring(0, dotIdx);
  }
  return fileName;
}

export class LocalMusicPlugin {
  static register(flutterEngine: FlutterEngine): void {
    const channel: MethodChannel = new MethodChannel(
      flutterEngine.dartExecutor,
      'com.mjiutang.ngskg/local_music'
    );

    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'scanMusic') {
          LocalMusicPlugin.scanMusic(result);
        } else {
          result.notImplemented();
        }
      }
    });
  }

  private static async scanMusic(result: MethodResult): Promise<void> {
    const audioList: AudioFileInfo[] = [];

    try {
      const scanDirs: string[] = [
        '/storage/media/',
        '/storage/media/100/local/files/'
      ];

      for (let d: number = 0; d < scanDirs.length; d++) {
        const dir: string = scanDirs[d];
        try {
          const files: string[] = fileIo.listFileSync(dir);
          for (let i: number = 0; i < files.length; i++) {
            const filePath: string = files[i];
            if (isAudioFile(filePath)) {
              const info: AudioFileInfo = new AudioFileInfo();
              const fileName: string = getFileName(filePath);
              info.title = getTitleFromFileName(fileName);
              info.filePath = filePath;
              info.id = 0;
              info.size = 0;
              info.duration = 0;

              try {
                const stat: fileIo.Stat = fileIo.statSync(filePath);
                info.size = Number(stat.size);
              } catch (e) {
                // stat may fail for some files
              }

              audioList.push(info);
            }
          }
        } catch (e) {
          // directory may not exist
        }
      }

      result.success(audioList);
    } catch (e) {
      result.success([]);
    }
  }
}
