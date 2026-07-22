import { avSession } from '@kit.AvSessionKit';
import { MethodChannel, MethodCall, MethodResult, FlutterEngine, BasicMessageChannel, StringCodec } from '@ohos/flutter_ohos';

class MediaMetadataArgs {
  title: string;
  artist: string;
  albumArtUrl: string;
  duration: number;
  lyricLine: string;

  constructor() {
    this.title = '';
    this.artist = '';
    this.albumArtUrl = '';
    this.duration = 0;
    this.lyricLine = '';
  }
}

class PlaybackStateArgs {
  isPlaying: boolean;
  position: number;
  isBuffering: boolean;

  constructor() {
    this.isPlaying = false;
    this.position = 0;
    this.isBuffering = false;
  }
}

class CustomButtonArgs {
  liked: boolean;
  playMode: string;

  constructor() {
    this.liked = false;
    this.playMode = 'sequential';
  }
}

function readStringField(args: Object | null, key: string, defaultValue: string): string {
  if (args === null || args === undefined) {
    return defaultValue;
  }
  const rec: Record<string, Object> = args as Record<string, Object>;
  const val: Object | undefined = rec[key];
  if (typeof val === 'string') {
    return val as string;
  }
  return defaultValue;
}

function readNumberField(args: Object | null, key: string, defaultValue: number): number {
  if (args === null || args === undefined) {
    return defaultValue;
  }
  const rec: Record<string, Object> = args as Record<string, Object>;
  const val: Object | undefined = rec[key];
  if (typeof val === 'number') {
    return val as number;
  }
  return defaultValue;
}

function readBooleanField(args: Object | null, key: string, defaultValue: boolean): boolean {
  if (args === null || args === undefined) {
    return defaultValue;
  }
  const rec: Record<string, Object> = args as Record<string, Object>;
  const val: Object | undefined = rec[key];
  if (typeof val === 'boolean') {
    return val as boolean;
  }
  return defaultValue;
}

function parseMediaMetadataArgs(args: Object | null): MediaMetadataArgs {
  const result: MediaMetadataArgs = new MediaMetadataArgs();
  result.title = readStringField(args, 'title', '');
  result.artist = readStringField(args, 'artist', '');
  result.albumArtUrl = readStringField(args, 'albumArtUrl', '');
  result.duration = readNumberField(args, 'duration', 0);
  result.lyricLine = readStringField(args, 'lyricLine', '');
  return result;
}

function parsePlaybackStateArgs(args: Object | null): PlaybackStateArgs {
  const result: PlaybackStateArgs = new PlaybackStateArgs();
  result.isPlaying = readBooleanField(args, 'isPlaying', false);
  result.position = readNumberField(args, 'position', 0);
  result.isBuffering = readBooleanField(args, 'isBuffering', false);
  return result;
}

function parseCustomButtonArgs(args: Object | null): CustomButtonArgs {
  const result: CustomButtonArgs = new CustomButtonArgs();
  result.liked = readBooleanField(args, 'liked', false);
  result.playMode = readStringField(args, 'playMode', 'sequential');
  return result;
}

export class MediaSessionPlugin {
  private session: avSession.AVSession | undefined = undefined;
  private sessionChannel: MethodChannel | null = null;
  private callbackChannel: BasicMessageChannel<string> | null = null;
  private isActive: boolean = false;
  private currentPlaybackState: PlaybackStateArgs = new PlaybackStateArgs();
  private isLiked: boolean = false;
  private playModeLabel: string = 'sequential';

  static create(
    flutterEngine: FlutterEngine,
    onPrev: () => void,
    onPlayPause: () => void,
    onNext: () => void,
    onLike: () => void,
    onSwitchMode: () => void,
    onSeekTo: (posMs: number) => void
  ): MediaSessionPlugin {
    const plugin: MediaSessionPlugin = new MediaSessionPlugin();
    plugin.init(
      flutterEngine,
      onPrev,
      onPlayPause,
      onNext,
      onLike,
      onSwitchMode,
      onSeekTo
    );
    return plugin;
  }

  private init(
    flutterEngine: FlutterEngine,
    onPrev: () => void,
    onPlayPause: () => void,
    onNext: () => void,
    onLike: () => void,
    onSwitchMode: () => void,
    onSeekTo: (posMs: number) => void
  ): void {
    this.sessionChannel = new MethodChannel(
      flutterEngine.dartExecutor,
      'com.mjiutang.ngskg/media_session'
    );

    this.sessionChannel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handleMethodCall(call, result);
      }
    });

    this.callbackChannel = new BasicMessageChannel<string>(
      flutterEngine.dartExecutor,
      'com.mjiutang.ngskg/media_callbacks',
      StringCodec.INSTANCE
    );

    this.setupCallbacks(onPrev, onPlayPause, onNext, onLike, onSwitchMode, onSeekTo);
  }

  private handleMethodCall(call: MethodCall, result: MethodResult): void {
    const method: string = call.method;
    const args: Object | null = call.args;

    if (method === 'updateMetadata') {
      const metadataArgs: MediaMetadataArgs = parseMediaMetadataArgs(args);
      this.updateMetadata(metadataArgs);
      result.success(null);
    } else if (method === 'updatePlaybackState') {
      const stateArgs: PlaybackStateArgs = parsePlaybackStateArgs(args);
      this.updatePlaybackState(stateArgs);
      result.success(null);
    } else if (method === 'updateCustomButtons') {
      const buttonArgs: CustomButtonArgs = parseCustomButtonArgs(args);
      this.updateCustomButtons(buttonArgs);
      result.success(null);
    } else if (method === 'release') {
      this.release();
      result.success(null);
    } else {
      result.notImplemented();
    }
  }

  private updateMetadata(args: MediaMetadataArgs): void {
    if (this.session === undefined || !this.isActive) {
      return;
    }

    const metadata: avSession.AVMetadata = {
      assetId: '',
      title: args.title,
      artist: args.artist,
      author: args.artist,
      duration: args.duration * 1000,
      mediaImage: args.albumArtUrl,
      lyric: args.lyricLine
    };

    this.session.setAVMetadata(metadata);
  }

  private updatePlaybackState(args: PlaybackStateArgs): void {
    this.currentPlaybackState = args;
    this.pushPlaybackState();
  }

  private updateCustomButtons(args: CustomButtonArgs): void {
    this.isLiked = args.liked;
    this.playModeLabel = args.playMode;
    this.pushPlaybackState();
  }

  private pushPlaybackState(): void {
    if (this.session === undefined || !this.isActive) {
      return;
    }

    const args: PlaybackStateArgs = this.currentPlaybackState;
    let stateValue: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    if (args.isBuffering) {
      stateValue = avSession.PlaybackState.PLAYBACK_STATE_BUFFERING;
    } else if (args.isPlaying) {
      stateValue = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    }

    const loopMode: avSession.LoopMode = this.mapPlayModeToLoopMode(this.playModeLabel);

    const state: avSession.AVPlaybackState = {
      state: stateValue,
      position: {
        elapsedTime: args.position * 1000,
        updateTime: Date.now()
      },
      speed: 1.0,
      isFavorite: this.isLiked,
      loopMode: loopMode
    };

    this.session.setAVPlaybackState(state);
  }

  private mapPlayModeToLoopMode(playMode: string): avSession.LoopMode {
    if (playMode === 'shuffle') {
      return avSession.LoopMode.LOOP_MODE_SHUFFLE;
    }
    if (playMode === 'repeatOne') {
      return avSession.LoopMode.LOOP_MODE_SINGLE;
    }
    return avSession.LoopMode.LOOP_MODE_SEQUENCE;
  }

  async createSession(context: Context): Promise<void> {
    if (this.session !== undefined) {
      return;
    }

    const newSession: avSession.AVSession = await avSession.createAVSession(
      context,
      'ngskg_media',
      'audio'
    );
    this.session = newSession;
    await this.session.activate();
    this.isActive = true;
  }

  release(): void {
    if (this.session !== undefined) {
      if (this.isActive) {
        this.session.deactivate();
      }
      this.session.destroy();
      this.session = undefined;
      this.isActive = false;
    }
  }

  private setupCallbacks(
    onPrev: () => void,
    onPlayPause: () => void,
    onNext: () => void,
    onLike: () => void,
    onSwitchMode: () => void,
    onSeekTo: (posMs: number) => void
  ): void {
    if (this.session === undefined) {
      return;
    }

    this.session.on('play', (): void => {
      onPlayPause();
      this.sendFlutterCallback('onPlayPause');
    });

    this.session.on('pause', (): void => {
      onPlayPause();
      this.sendFlutterCallback('onPlayPause');
    });

    this.session.on('stop', (): void => {
      this.sendFlutterCallback('onPlayPause');
    });

    this.session.on('playPrevious', (): void => {
      onPrev();
      this.sendFlutterCallback('onPrev');
    });

    this.session.on('playNext', (): void => {
      onNext();
      this.sendFlutterCallback('onNext');
    });

    this.session.on('seek', (time: number): void => {
      onSeekTo(time);
      const msg: string = 'onSeekTo|' + time.toString();
      this.sendFlutterCallback(msg);
    });

    this.session.on('toggleFavorite', (assetId: string): void => {
      onLike();
      this.sendFlutterCallback('onLike');
    });
  }

  private sendFlutterCallback(message: string): void {
    if (this.callbackChannel !== null) {
      this.callbackChannel.send(message);
    }
  }
}
