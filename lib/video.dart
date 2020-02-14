import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_playout/player_state.dart';

/// Video plugin for playing HLS stream using native player. [autoPlay] flag
/// controls whether to start playback as soon as player is ready. To show/hide
/// player controls, use [showControls] flag. The [title] and [subtitle] are
/// used for lock screen info panel on both iOS & Android. The [isLiveStream]
/// flag is only used on iOS to change the scrub-bar look on lock screen info
/// panel. It has no affect on the actual functionality of the plugin. Defaults
/// to false. Use [onViewCreated] callback to get notified once the underlying
/// [PlatformView] is setup. The [desiredState] enum can be used to control
/// play/pause. If the value change, the widget will make sure that player is
/// in sync with the new state.
class Video extends StatefulWidget {
  final bool autoPlay;
  final bool showControls;
  final String url;
  final String title;
  final String subtitle;
  final bool isLiveStream;
  final Function onViewCreated;
  final PlayerState desiredState;
  final double aspectRatio;

  const Video(
      {Key key,
      this.autoPlay = false,
      this.showControls = true,
      this.url,
      this.title = "",
      this.subtitle = "",
      this.isLiveStream = false,
      this.onViewCreated,
      this.desiredState = PlayerState.PLAYING,
      this.aspectRatio = 16 / 9})
      : super(key: key);

  @override
  _VideoState createState() => _VideoState();
}

class _VideoState extends State<Video> {
  MethodChannel _methodChannel;
  int _platformViewId;
  Widget _playerWidget = Container();

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: _playerWidget,
    );
  }

  void _setupPlayer() {
    if (widget.url != null && widget.url.isNotEmpty) {
      /* Android */
      if (Platform.isAndroid) {
        _playerWidget = AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: AndroidView(
              viewType: 'tv.mta/NativeVideoPlayer',
              creationParams: {
                "autoPlay": widget.autoPlay,
                "showControls": widget.showControls,
                "url": widget.url,
                "title": widget.title ?? "",
                "subtitle": widget.subtitle ?? "",
                "isLiveStream": widget.isLiveStream,
                "aspectRatio": widget.aspectRatio,
              },
              creationParamsCodec: const JSONMessageCodec(),
              onPlatformViewCreated: (viewId) {
                _onPlatformViewCreated(viewId);
                if (widget.onViewCreated != null) {
                  widget.onViewCreated(viewId);
                }
              },
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
                new Factory<OneSequenceGestureRecognizer>(
                  () => new EagerGestureRecognizer(),
                ),
              ].toSet(),
            ));
      }

      /* iOS */
      else if (Platform.isIOS) {
        _playerWidget = AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: UiKitView(
              viewType: 'tv.mta/NativeVideoPlayer',
              creationParams: {
                "autoPlay": widget.autoPlay,
                "showControls": widget.showControls,
                "url": widget.url,
                "title": widget.title ?? "",
                "subtitle": widget.subtitle ?? "",
                "isLiveStream": widget.isLiveStream,
                "aspectRatio": widget.aspectRatio,
              },
              creationParamsCodec: const JSONMessageCodec(),
              onPlatformViewCreated: (viewId) {
                _onPlatformViewCreated(viewId);
                if (widget.onViewCreated != null) {
                  widget.onViewCreated(viewId);
                }
              },
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
                new Factory<OneSequenceGestureRecognizer>(
                  () => new EagerGestureRecognizer(),
                ),
              ].toSet(),
            ));
      }
    }
  }

  @override
  void didUpdateWidget(Video oldWidget) {
    if (widget.url == null || widget.url.isEmpty) {
      _disposePlatformView();
    }
    if (oldWidget.url != widget.url ||
        oldWidget.title != widget.title ||
        oldWidget.subtitle != widget.subtitle ||
        oldWidget.isLiveStream != widget.isLiveStream) {
      _onMediaChanged();
    }
    if (oldWidget.desiredState != widget.desiredState) {
      _onDesiredStateChanged(oldWidget);
    }
    if (oldWidget.showControls != widget.showControls) {
      _onShowControlsFlagChanged();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _disposePlatformView(isDisposing: true);
    super.dispose();
  }

  void _onPlatformViewCreated(int viewId) {
    _platformViewId = viewId;
    _methodChannel =
        MethodChannel("tv.mta/NativeVideoPlayerMethodChannel_$viewId");
  }

  /// The [desiredState] flag has changed so need to update playback to
  /// reflect the new state.
  void _onDesiredStateChanged(Video oldWidget) async {
    switch (widget.desiredState) {
      case PlayerState.PLAYING:
        _resumePlayback();
        break;
      case PlayerState.PAUSED:
        _pausePlayback();
        break;
      case PlayerState.STOPPED:
        _pausePlayback();
        break;
    }
  }

  void _onShowControlsFlagChanged() async {
    _methodChannel.invokeMethod("onShowControlsFlagChanged", {
      "showControls": widget.showControls,
    });
  }

  void _pausePlayback() async {
    if (_methodChannel != null) {
      _methodChannel.invokeMethod("pause");
    }
  }

  void _resumePlayback() async {
    if (_methodChannel != null) {
      _methodChannel.invokeMethod("resume");
    }
  }

  void _onMediaChanged() {
    if (widget.url != null && _methodChannel != null) {
      _methodChannel.invokeMethod("onMediaChanged", {
        "autoPlay": widget.autoPlay,
        "url": widget.url,
        "title": widget.title,
        "subtitle": widget.subtitle,
        "isLiveStream": widget.isLiveStream,
        "showControls": widget.showControls,
        "aspectRatio": widget.aspectRatio,
      });
    }
  }

  void _disposePlatformView({bool isDisposing = false}) async {
    if (_methodChannel != null && _platformViewId != null) {
      _methodChannel.invokeMethod("dispose");

      if (!isDisposing) {
        setState(() {
          _methodChannel = null;
        });
      }
    }
  }
}
