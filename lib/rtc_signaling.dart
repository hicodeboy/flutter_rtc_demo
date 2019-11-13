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

  Map<String, RTCPeerConnection> _peerConnections =
      Map<String, RTCPeerConnection>();

  MediaStream _localStream;
  List<MediaStream> _remoteStreams;

  SignalingStateCallback onStateChange;

  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;

  JsonDecoder _decoder = JsonDecoder();

  JsonEncoder _encoder = JsonEncoder();

  /*
  * turn 、 stun服务器的地址
  * */
  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'turn:stun.l.supercodeboy.com:3478'},
    ]
  };

  /*
  * DTLS 是否开启
  * */
  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  /*
  * 音视频约束
  * */
  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  RTCSignaling({this.url, this.display});

  // socket连接

  void connect() async {
    _channel = IOWebSocketChannel.connect(url);

    _channel.stream.listen((message) {
      print('收到的内容 ： $message');
    }).onDone(() {
      print('closed by server!');
    });
  }

  // 创建本地媒体流
  Future<MediaStream> createStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    if (this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    return stream;
  }

  // 关闭本地媒体，断开socket

  void close() {
    if (_localStream != null) {
      _localStream.dispose();
      _localStream = null;
    }

    _peerConnections.forEach((key, pc) {
      pc.close();
    });

    if (_channel != null) _channel.sink.close();
  }

  // 切换前后摄像头
  void switchCamera() {
    _localStream?.getVideoTracks()[0].switchCamera();
  }
}
