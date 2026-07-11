import 'dart:async';
import 'dart:io' show Platform;

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../providers/player_provider.dart';

// ignore_for_file: unused_field

/// MPRIS D-Bus service for Linux desktop media integration.
///
/// Registers [org.mpris.MediaPlayer2](https://specifications.freedesktop.org/mpris-spec/latest/)
/// on the session bus, allowing desktop environments (GNOME, KDE, etc.) to
/// control playback and display now-playing metadata.
///
/// Only available on Linux (no-op elsewhere).
class LinuxMprisService {
  static const _busName = 'org.mpris.MediaPlayer2.ngskg_plus';
  static final _objectPath = DBusObjectPath('/org/mpris/MediaPlayer2');
  static const _trackIdBase = '/org/mpris/MediaPlayer2/Track';

  DBusClient? _client;
  MprisPlayerObject? _object;
  PlayerProvider? _player;
  int _trackSeq = 0;
  bool _initialized = false;

  Future<void> init(PlayerProvider player) async {
    if (_initialized || !Platform.isLinux) return;
    _initialized = true;
    _player = player;

    try {
      _client = DBusClient.session();
      await _client!.requestName(_busName);
      _object = MprisPlayerObject(_objectPath, this, player);
      await _client!.registerObject(_object!);
      debugPrint('LinuxMprisService: Registered on session bus as $_busName');
    } catch (e) {
      debugPrint('LinuxMprisService: Failed to init: $e');
    }
  }

  /// Syncs current player state to MPRIS.
  void sync({
    dynamic song,
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    String? lyricText,
  }) {
    final obj = _object;
    if (obj == null) return;

    if (song != null) {
      _trackSeq++;
      obj.updateMetadata(song, _trackIdForSeq(_trackSeq));
    }
    if (isPlaying != null) {
      obj.updatePlaybackStatus(isPlaying);
    }
  }

  String _trackIdForSeq(int seq) => '$_trackIdBase/$seq';

  Future<void> dispose() async {
    if (_object != null) {
      try {
        await _client?.unregisterObject(_object!);
      } catch (_) {}
      _object = null;
    }
    await _client?.close();
    _client = null;
    _initialized = false;
  }
}

// ─────────────────────────────────────────────────────────────
//  D-Bus object implementing MPRIS
// ─────────────────────────────────────────────────────────────

class MprisPlayerObject extends DBusObject {
  final LinuxMprisService _service;
  final PlayerProvider _player;

  // Cached property values for Properties.Get/GetAll
  String _playbackStatus = 'Stopped';
  String _currentTrackId = '/';
  String _currentTitle = '';
  String _currentArtist = '';
  String _currentAlbum = '';
  String _currentArtUrl = '';
  int _currentLength = 0; // microseconds

  MprisPlayerObject(DBusObjectPath path, this._service, this._player)
      : super(path);

  // ── Public API (called from LinuxMprisService.sync()) ──

  void updateMetadata(dynamic song, String trackId) {
    _currentTrackId = trackId;
    _currentTitle = song.name ?? '';
    _currentArtist = song.artistDisplay ?? '';
    _currentAlbum = song.albumName ?? '';
    _currentArtUrl = song.albumCoverUrl ?? '';
    _currentLength = (_player.duration.inMilliseconds * 1000);
    _emitMetadataChanged();
  }

  void updatePlaybackStatus(bool isPlaying) {
    _playbackStatus = isPlaying ? 'Playing' : 'Paused';
    emitPropertiesChanged('org.mpris.MediaPlayer2.Player', changedProperties: {
      'PlaybackStatus': DBusString(_playbackStatus),
    });
  }

  // ── Introspection ──

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      _introspectMediaPlayer2(),
      _introspectPlayer(),
    ];
  }

  DBusIntrospectInterface _introspectMediaPlayer2() {
    return DBusIntrospectInterface('org.mpris.MediaPlayer2', properties: [
      DBusIntrospectProperty('Identity', DBusSignature('s'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('DesktopEntry', DBusSignature('s'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanQuit', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanRaise', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('HasTrackList', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('SupportedUriSchemes', DBusSignature('as'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('SupportedMimeTypes', DBusSignature('as'),
          access: DBusPropertyAccess.read),
    ], methods: [
      DBusIntrospectMethod('Raise'),
      DBusIntrospectMethod('Quit'),
    ]);
  }

  DBusIntrospectInterface _introspectPlayer() {
    return DBusIntrospectInterface('org.mpris.MediaPlayer2.Player', properties: [
      DBusIntrospectProperty('PlaybackStatus', DBusSignature('s'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('LoopStatus', DBusSignature('s'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('Rate', DBusSignature('d'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('Shuffle', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('Metadata', DBusSignature('a{sv}'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('Volume', DBusSignature('d'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('Position', DBusSignature('x'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('MinimumRate', DBusSignature('d'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('MaximumRate', DBusSignature('d'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanGoNext', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanGoPrevious', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanPlay', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanPause', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanSeek', DBusSignature('b'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('CanControl', DBusSignature('b'),
          access: DBusPropertyAccess.read),
    ], methods: [
      DBusIntrospectMethod('Next'),
      DBusIntrospectMethod('Previous'),
      DBusIntrospectMethod('Pause'),
      DBusIntrospectMethod('PlayPause'),
      DBusIntrospectMethod('Stop'),
      DBusIntrospectMethod('Play'),
      DBusIntrospectMethod('Seek', args: [
        DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_,
            name: 'Offset'),
      ]),
      DBusIntrospectMethod('SetPosition', args: [
        DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.in_,
            name: 'TrackId'),
        DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_,
            name: 'Position'),
      ]),
    ], signals: [
      DBusIntrospectSignal('Seeked', args: [
        DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.out,
            name: 'Position'),
      ]),
    ]);
  }

  // ── Method calls ──

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    // Handle org.freedesktop.DBus.Properties methods
    if (call.interface == 'org.freedesktop.DBus.Properties') {
      return _handlePropertiesCall(call);
    }

    if (call.interface == 'org.mpris.MediaPlayer2') {
      return _handleMediaPlayer2Call(call);
    }

    if (call.interface == 'org.mpris.MediaPlayer2.Player') {
      return _handlePlayerCall(call);
    }

    return DBusMethodErrorResponse.unknownInterface();
  }

  Future<DBusMethodResponse> _handlePropertiesCall(DBusMethodCall call) async {
    if (call.name == 'Get') {
      final iface = call.values[0].asString();
      final prop = call.values[1].asString();
      return _getProperty(iface, prop);
    }
    if (call.name == 'GetAll') {
      final iface = call.values[0].asString();
      return _getAllProperties(iface);
    }
    if (call.name == 'Set') {
      return DBusMethodErrorResponse.notSupported();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  Future<DBusMethodResponse> _handleMediaPlayer2Call(
      DBusMethodCall call) async {
    switch (call.name) {
      case 'Raise':
        // No-op: we don't raise the window via D-Bus
        return DBusMethodSuccessResponse([]);
      case 'Quit':
        return DBusMethodSuccessResponse([]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  Future<DBusMethodResponse> _handlePlayerCall(DBusMethodCall call) async {
    switch (call.name) {
      case 'Play':
        if (!_player.isPlaying) _player.togglePlayPause();
        return DBusMethodSuccessResponse([]);
      case 'Pause':
        if (_player.isPlaying) _player.togglePlayPause();
        return DBusMethodSuccessResponse([]);
      case 'PlayPause':
        _player.togglePlayPause();
        return DBusMethodSuccessResponse([]);
      case 'Stop':
        if (_player.isPlaying) _player.togglePlayPause();
        return DBusMethodSuccessResponse([]);
      case 'Next':
        _player.playNext();
        return DBusMethodSuccessResponse([]);
      case 'Previous':
        _player.playPrevious();
        return DBusMethodSuccessResponse([]);
      case 'Seek':
        // Seek by offset in microseconds
        if (call.values.isNotEmpty) {
          final offsetUs = call.values[0].asInt64();
          final newPos = _player.position.inMilliseconds + (offsetUs ~/ 1000);
          _player.seek(Duration(milliseconds: newPos.clamp(0, _player.duration.inMilliseconds)));
        }
        return DBusMethodSuccessResponse([]);
      case 'SetPosition':
        if (call.values.length >= 2) {
          final posUs = call.values[1].asInt64();
          _player.seek(Duration(microseconds: posUs));
        }
        return DBusMethodSuccessResponse([]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  // ── Properties (Get / GetAll) ──

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    return _getProperty(interface, name);
  }

  Future<DBusMethodResponse> _getProperty(String interface, String name) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      return _mediaPlayer2Prop(name);
    }
    if (interface == 'org.mpris.MediaPlayer2.Player') {
      return _playerProp(name);
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    return _getAllProperties(interface);
  }

  Future<DBusMethodResponse> _getAllProperties(String interface) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      return DBusGetAllPropertiesResponse({
        'Identity': DBusString('NGS-KG+'),
        'DesktopEntry': DBusString('ngskg_plus'),
        'CanQuit': DBusBoolean(false),
        'CanRaise': DBusBoolean(false),
        'HasTrackList': DBusBoolean(false),
        'SupportedUriSchemes': DBusArray.string([]),
        'SupportedMimeTypes': DBusArray.string([]),
      });
    }
    if (interface == 'org.mpris.MediaPlayer2.Player') {
      return DBusGetAllPropertiesResponse({
        'PlaybackStatus': DBusString(_playbackStatus),
        'LoopStatus': DBusString('None'),
        'Rate': DBusDouble(1.0),
        'Shuffle': DBusBoolean(false),
        'Metadata': _buildMetadataDict(),
        'Volume': DBusDouble(1.0),
        'Position': DBusInt64(_player.position.inMicroseconds),
        'MinimumRate': DBusDouble(1.0),
        'MaximumRate': DBusDouble(1.0),
        'CanGoNext': DBusBoolean(true),
        'CanGoPrevious': DBusBoolean(true),
        'CanPlay': DBusBoolean(true),
        'CanPause': DBusBoolean(true),
        'CanSeek': DBusBoolean(true),
        'CanControl': DBusBoolean(true),
      });
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  DBusMethodResponse _mediaPlayer2Prop(String name) {
    switch (name) {
      case 'Identity':
        return DBusGetPropertyResponse(DBusString('NGS-KG+'));
      case 'DesktopEntry':
        return DBusGetPropertyResponse(DBusString('ngskg_plus'));
      case 'CanQuit':
        return DBusGetPropertyResponse(DBusBoolean(false));
      case 'CanRaise':
        return DBusGetPropertyResponse(DBusBoolean(false));
      case 'HasTrackList':
        return DBusGetPropertyResponse(DBusBoolean(false));
      case 'SupportedUriSchemes':
        return DBusGetPropertyResponse(DBusArray.string([]));
      case 'SupportedMimeTypes':
        return DBusGetPropertyResponse(DBusArray.string([]));
      default:
        return DBusMethodErrorResponse.unknownProperty();
    }
  }

  DBusMethodResponse _playerProp(String name) {
    switch (name) {
      case 'PlaybackStatus':
        return DBusGetPropertyResponse(DBusString(_playbackStatus));
      case 'LoopStatus':
        return DBusGetPropertyResponse(DBusString('None'));
      case 'Rate':
        return DBusGetPropertyResponse(DBusDouble(1.0));
      case 'Shuffle':
        return DBusGetPropertyResponse(DBusBoolean(false));
      case 'Metadata':
        return DBusGetPropertyResponse(_buildMetadataDict());
      case 'Volume':
        return DBusGetPropertyResponse(DBusDouble(1.0));
      case 'Position':
        return DBusGetPropertyResponse(
            DBusInt64(_player.position.inMicroseconds));
      case 'MinimumRate':
        return DBusGetPropertyResponse(DBusDouble(1.0));
      case 'MaximumRate':
        return DBusGetPropertyResponse(DBusDouble(1.0));
      case 'CanGoNext':
        return DBusGetPropertyResponse(DBusBoolean(true));
      case 'CanGoPrevious':
        return DBusGetPropertyResponse(DBusBoolean(true));
      case 'CanPlay':
        return DBusGetPropertyResponse(DBusBoolean(true));
      case 'CanPause':
        return DBusGetPropertyResponse(DBusBoolean(true));
      case 'CanSeek':
        return DBusGetPropertyResponse(DBusBoolean(true));
      case 'CanControl':
        return DBusGetPropertyResponse(DBusBoolean(true));
      default:
        return DBusMethodErrorResponse.unknownProperty();
    }
  }

  // ── Metadata helpers ──

  DBusDict _buildMetadataDict() {
    final entries = <String, DBusValue>{
      'mpris:trackid': DBusObjectPath(_currentTrackId),
      'mpris:length': DBusInt64(_currentLength),
      'xesam:title': DBusString(_currentTitle),
      'xesam:album': DBusString(_currentAlbum),
    };
    if (_currentArtist.isNotEmpty) {
      entries['xesam:artist'] =
          DBusArray(DBusSignature('s'), [DBusString(_currentArtist)]);
    }
    if (_currentArtUrl.isNotEmpty) {
      entries['mpris:artUrl'] = DBusString(_currentArtUrl);
    }
    return DBusDict.stringVariant(entries);
  }

  void _emitMetadataChanged() {
    emitPropertiesChanged('org.mpris.MediaPlayer2.Player', changedProperties: {
      'PlaybackStatus': DBusString(_playbackStatus),
      'Metadata': _buildMetadataDict(),
    });
  }
}
