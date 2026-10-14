import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound effects (Kenney, CC0) by meaning, so screens never hard-code files.
enum Sfx {
  tap('audio/sfx/click_002.ogg'),
  confirm('audio/sfx/confirmation_002.ogg'),
  error('audio/sfx/error_004.ogg'),
  select('audio/sfx/select_003.ogg'),
  toggle('audio/sfx/toggle_002.ogg'),
  back('audio/sfx/back_002.ogg'),
  open('audio/sfx/open_002.ogg'),
  levelUp('audio/sfx/maximize_006.ogg'),
  feed('audio/sfx/drop_002.ogg'),
  hit('audio/sfx/impactPunch_medium_001.ogg'),
  heavyHit('audio/sfx/impactPunch_heavy_000.ogg'),
  guard('audio/sfx/impactPlate_light_002.ogg'),
  rockHit('audio/sfx/impactMining_001.ogg'),
  softHit('audio/sfx/impactSoft_heavy_002.ogg'),
  victory('audio/sfx/jingles_PIZZI10.ogg'),
  defeat('audio/sfx/jingles_PIZZI05.ogg'),
  reward('audio/sfx/jingles_STEEL00.ogg'),
  achievement('audio/sfx/jingles_HIT02.ogg'),
  coins('audio/sfx/handleCoins.ogg'),
  page('audio/sfx/bookFlip2.ogg'),
  equip('audio/sfx/cloth2.ogg');

  const Sfx(this.asset);

  final String asset;
}

abstract class SoundService {
  void play(Sfx sfx);

  /// Starts (or restarts) the background music if it is enabled.
  void startMusic();
  void stopMusic();

  /// Pauses music while the app is in the background, and resumes it.
  void pauseForBackground();
  void resumeFromBackground();
  void configure({
    required bool music,
    required bool sfx,
    required double musicVolume,
  });
  void dispose();
}

class SilentSound implements SoundService {
  const SilentSound();

  @override
  void play(Sfx sfx) {}
  @override
  void startMusic() {}
  @override
  void stopMusic() {}
  @override
  void pauseForBackground() {}
  @override
  void resumeFromBackground() {}
  @override
  void configure({
    required bool music,
    required bool sfx,
    required double musicVolume,
  }) {}
  @override
  void dispose() {}
}

/// audioplayers-backed sound. Every call is fire-and-forget and swallows
/// errors: a missing codec or blocked autoplay must never break the game.
///
/// Sound effects mix with the music instead of taking Android's audio
/// focus. With the default focus mode each effect requested exclusive focus,
/// which made Android pause the music after the first button sound.
class GameSound implements SoundService {
  GameSound() {
    final mix = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
        .build();
    for (final p in _pool) {
      _guard(() => p.setAudioContext(mix));
    }
    _guard(() => _music.setReleaseMode(ReleaseMode.loop));
    _music.onPlayerStateChanged.listen(
      (state) => _musicState = state,
      onError: (Object e) => debugPrint('sound: $e'),
    );
  }

  static const _musicAsset = 'audio/music/the_world_at_your_door.mp3';

  final AudioPlayer _music = AudioPlayer(playerId: 'music');
  final List<AudioPlayer> _pool = List.generate(
    4,
    (i) => AudioPlayer(playerId: 'sfx$i'),
  );
  int _next = 0;
  bool _musicOn = true;
  bool _sfxOn = true;
  double _volume = 0.45;

  /// True between startMusic and stopMusic (what the game wants).
  bool _wantMusic = false;
  bool _inBackground = false;
  PlayerState _musicState = PlayerState.stopped;

  @override
  void configure({
    required bool music,
    required bool sfx,
    required double musicVolume,
  }) {
    _musicOn = music;
    _sfxOn = sfx;
    _volume = musicVolume;
    _guard(() => _music.setVolume(_volume));
    if (!_musicOn) stopMusic();
  }

  @override
  void play(Sfx sfx) {
    if (!_sfxOn || _inBackground) return;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    _guard(() async {
      await player.stop();
      await player.play(AssetSource(sfx.asset), volume: 0.8);
    });
  }

  @override
  void startMusic() {
    if (!_musicOn) return;
    _wantMusic = true;
    if (_inBackground || _musicState == PlayerState.playing) return;
    _guard(() async {
      if (_musicState == PlayerState.paused) {
        await _music.resume();
      } else {
        await _music.play(AssetSource(_musicAsset), volume: _volume);
      }
    });
  }

  @override
  void stopMusic() {
    _wantMusic = false;
    _guard(() => _music.stop());
  }

  @override
  void pauseForBackground() {
    _inBackground = true;
    if (_musicState == PlayerState.playing) _guard(() => _music.pause());
  }

  @override
  void resumeFromBackground() {
    _inBackground = false;
    if (_wantMusic) startMusic();
  }

  @override
  void dispose() {
    _guard(() => _music.dispose());
    for (final p in _pool) {
      _guard(() => p.dispose());
    }
  }

  void _guard(Future<void> Function() action) {
    try {
      action().catchError((Object e) => debugPrint('sound: $e'));
    } catch (e) {
      debugPrint('sound: $e');
    }
  }
}
