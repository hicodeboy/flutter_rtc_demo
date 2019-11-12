import 'dart:convert';

import 'package:flutter_webrtc/webrtc.dart';
import 'package:random_string/random_string.dart';
import 'package:web_socket_channel/io.dart';

// 信令状态的回调
typedef void SignalingStateCallback();
// 媒体流的状态回调
typedef void StreamStateCallback(MediaStream stream);

// 对方进入房间的回调
typedef void OtherEventCallback(dynamic event);

// 信令状态
enum SignalingState {
  CallStateNew, // 新进入房间
  CallStateRinging,
  CallStateInvite,
  CallStateConnected, // 连接
  CallStateBye, // 离开
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

class RTCSignaling {
  final String _selfId = randomNumeric(6);

  IOWebSocketChannel _channel;

  String _sessionId; // 会话Id

  String url; // websocket url
  String display; // 展示名称

  Map _peerConnections = Map<String, RTCPeerConnection>();

  MediaStream _localStream;
  List<MediaStream> _remoteStreams;

  SignalingStateCallback onStateChange;

  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;

  JsonDecoder _decoder = JsonDecoder();

  JsonEncoder _encoder = JsonEncoder();


}
