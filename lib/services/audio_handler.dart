import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:PiliPlus/models/bangumi/info.dart';
import 'package:PiliPlus/models/video_detail_res.dart';
import 'package:PiliPlus/plugin/pl_player/index.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get_utils/get_utils.dart';

Future<VideoPlayerServiceHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => VideoPlayerServiceHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.piliplus.audio',
      androidNotificationChannelName: 'Audio Service PiliPlus',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      androidNotificationChannelDescription: 'Media notification channel',
      // androidNotificationIcon: 'drawable/ic_notification_icon',
    ),
  );
}

class VideoPlayerServiceHandler extends BaseAudioHandler with SeekHandler {
  static final List<MediaItem> _item = [];
  bool enableBackgroundPlay = true;
  // PlPlayerController player = PlPlayerController.getInstance();

  VideoPlayerServiceHandler() {
    revalidateSetting();
  }

  revalidateSetting() {
    enableBackgroundPlay = GStorage.setting
        .get(SettingBoxKey.enableBackgroundPlay, defaultValue: true);
  }

  @override
  Future<void> play() async {
    await PlPlayerController.playIfExists();
    // player.play();
  }

  @override
  Future<void> pause() async {
    await PlPlayerController.pauseIfExists();
    // player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
    await PlPlayerController.seekToIfExists(position, type: 'slider');
    // await player.seekTo(position);
  }

  Future<void> setMediaItem(MediaItem newMediaItem) async {
    if (!enableBackgroundPlay) return;
    // debugPrint("此时调用栈为：");
    // debugPrint(newMediaItem);
    // debugPrint(newMediaItem.title);
    // debugPrint(StackTrace.current.toString());
    if (!mediaItem.isClosed) mediaItem.add(newMediaItem);
  }

  Future<void> setPlaybackState(PlayerStatus status, bool isBuffering) async {
    if (!enableBackgroundPlay) return;

    final AudioProcessingState processingState;
    final playing = status == PlayerStatus.playing;
    if (status == PlayerStatus.completed) {
      processingState = AudioProcessingState.completed;
    } else if (isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else {
      processingState = AudioProcessingState.ready;
    }

    playbackState.add(playbackState.value.copyWith(
      processingState:
          isBuffering ? AudioProcessingState.buffering : processingState,
      controls: [
        MediaControl.rewind
            .copyWith(androidIcon: 'drawable/ic_baseline_replay_10_24'),
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward
            .copyWith(androidIcon: 'drawable/ic_baseline_forward_10_24'),
      ],
      playing: playing,
      systemActions: const {
        MediaAction.seek,
      },
    ));
  }

  onStatusChange(PlayerStatus status, bool isBuffering) {
    if (!enableBackgroundPlay) return;

    if (_item.isEmpty) return;
    setPlaybackState(status, isBuffering);
  }

  onVideoDetailChange(dynamic data, int cid) {
    if (!enableBackgroundPlay) return;
    // debugPrint('当前调用栈为：');
    // debugPrint(StackTrace.current);
    if (!PlPlayerController.instanceExists()) return;
    if (data == null) return;

    MediaItem? mediaItem;
    if (data is VideoDetailData) {
      if ((data.pages?.length ?? 0) > 1) {
        final current =
            data.pages?.firstWhereOrNull((element) => element.cid == cid);
        mediaItem = MediaItem(
          id: UniqueKey().toString(),
          title: current?.pagePart ?? "",
          artist: data.title ?? "",
          album: data.title ?? "",
          duration: Duration(seconds: current?.duration ?? 0),
          artUri: Uri.parse(data.pic ?? ""),
        );
      } else {
        mediaItem = MediaItem(
          id: UniqueKey().toString(),
          title: data.title ?? "",
          artist: data.owner?.name ?? "",
          duration: Duration(seconds: data.duration ?? 0),
          artUri: Uri.parse(data.pic ?? ""),
        );
      }
    } else if (data is BangumiInfoModel) {
      final current =
          data.episodes?.firstWhereOrNull((element) => element.cid == cid);
      mediaItem = MediaItem(
        id: UniqueKey().toString(),
        title: current?.longTitle ?? "",
        artist: data.title ?? "",
        duration: Duration(milliseconds: current?.duration ?? 0),
        artUri: Uri.parse(data.cover ?? ""),
      );
    }
    if (mediaItem == null) return;
    // debugPrint("exist: ${PlPlayerController.instanceExists()}");
    if (!PlPlayerController.instanceExists()) return;
    _item.add(mediaItem);
    setMediaItem(mediaItem);
  }

  onVideoDetailDispose() {
    if (!enableBackgroundPlay) return;

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    if (_item.isNotEmpty) {
      _item.removeLast();
    }
    if (_item.isNotEmpty) {
      setMediaItem(_item.last);
      stop();
    } else {
      clear();
    }
  }

  clear() {
    if (!enableBackgroundPlay) return;
    mediaItem.add(null);
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    _item.clear();
    stop();
  }

  onPositionChange(Duration position) {
    if (!enableBackgroundPlay) return;

    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
  }
}
