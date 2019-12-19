import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_webrtc/webrtc.dart';

import 'package:web_socket_channel/io.dart';

import 'package:random_string/random_string.dart';

// 信令状态
enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

/*
 * callbacks for Signaling API.
 */

// 信令状态的回调
typedef void SignalingStateCallback(SignalingState state);
// 媒体流的状态回调
typedef void StreamStateCallback(MediaStream stream);
// 对方进入房价回调
typedef void OtherEventCallback(dynamic event);

class RTCSignaling {
  final String _selfId = randomNumeric(6);
  IOWebSocketChannel _channel;

  String _sessionId;

  String url;
  String displayName;
  var _peerConnections = new Map<String, RTCPeerConnection>();

  MediaStream _localStream;
  List<MediaStream> _remoteStreams;
  SignalingStateCallback onStateChange;
  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;
  JsonDecoder _decoder = new JsonDecoder();
  JsonEncoder _encoder = JsonEncoder();

  /*
  * ice turn、stun 服务器 配置
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

  RTCSignaling({this.url, this.displayName});

  /*
  * socket 连接
  * */
  void connect() async {
    try {
      _channel = IOWebSocketChannel.connect(url);

      print('连接成功');
      this.onStateChange(SignalingState.ConnectionOpen);

      _channel.stream.listen((message) {
        print('receive $message');

        onMessage(message);
      }).onDone(() {
        print('Closed by server!');

        if (this.onStateChange != null) {
          this.onStateChange(SignalingState.ConnectionClosed);
        }
      });

      /*
      * 连接socket注册自己
      * */
      send('new', {
        'name': displayName,
        'id': _selfId,
        'user_agent': 'flutter-webrtc + ${Platform.operatingSystem}'
      });
    } catch (e) {
      print(e.toString());
      if (this.onStateChange != null) {
        this.onStateChange(SignalingState.ConnectionError);
      }
    }
  }

  /*
  * 创建本地媒体流
  * */
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

  /*
  * 关闭本地媒体，断开socket
  * */
  close() {
    if (_localStream != null) {
      _localStream.dispose();
      _localStream = null;
    }

    _peerConnections.forEach((key, pc) {
      pc.close();
    });

    if (_channel != null) _channel.sink.close();
  }

  /*
  * 切换前后摄像头
  * */
  void switchCamera() {
    if (_localStream != null) {
      _localStream.getVideoTracks()[0].switchCamera();
    }
  }

  /*
  * 邀请对方进行会话
  * */
  void invite(String peer_id) {
    this._sessionId = '$_selfId-$peer_id}';

    if (this.onStateChange != null) {
      this.onStateChange(SignalingState.CallStateNew);
    }

    /*
    * 创建一个peerconnection
    * */
    _createPeerConnection(peer_id).then((pc) {
      _peerConnections[peer_id] = pc;
      //
      _createOffer(peer_id, pc);
    });
  }

  /*
  * 收到消息处理逻辑
  * */
  void onMessage(message) async {
    Map<String, dynamic> mapData = _decoder.convert(message);

    var data = mapData['data'];

    switch (mapData['type']) {
      /*
      * 新成员加入刷新界面
      * */
      case 'peers':
        {
          List<dynamic> peers = data;
          if (this.onPeersUpdate != null) {
            Map<String, dynamic> event = Map<String, dynamic>();
            event['self'] = _selfId;
            event['peers'] = peers;
            this.onPeersUpdate(event);
          }
        }
        break;

      /*
      * 获取远端的offer
      * */
      case 'offer':
        {
          String id = data['from'];

          print('offer from $id ');
          var description = data['description'];
          var sessionId = data['session_id'];
          this._sessionId = sessionId;

          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateNew);
          }
          /*
          * 收到远端offer后 创建本地的peerconnection
          * 之后设置远端的媒体信息,并向对端发送answer进行应答
          * */
          _createPeerConnection(id).then((pc) {
            _peerConnections[id] = pc;
            pc.setRemoteDescription(
                RTCSessionDescription(description['sdp'], description['type']));
            _createAnswer(id, pc);
          });
        }
        break;

      /*
      * 收到对端 answer
      * */
      case 'answer':
        {
          String id = data['from'];

          print('answer from $id ');
          Map description = data['description'];

          RTCPeerConnection pc = _peerConnections[id];
          if (pc != null) {
            // 给peerconnection设置remote媒体信息
            pc.setRemoteDescription(
                RTCSessionDescription(description['sdp'], description['type']));
          }
        }
        break;
      /*
      * 收到远端的候选者，并添加给候选者
      * */
      case 'candidate':
        {
          String id = data['from'];

          print('candidate from $id ');
          Map candidateMap = data['candidate'];
          RTCPeerConnection pc = _peerConnections[id];

          if (pc != null) {
            RTCIceCandidate candidate = new RTCIceCandidate(
                candidateMap['candidate'],
                candidateMap['sdpMid'],
                candidateMap['sdpMLineIndex']);
            pc.addCandidate(candidate);
          }
        }
        break;

      /*
      * 对方离开，断开连接
      * */
      case 'leave':
        {
          var id = data;
          _peerConnections.remove(id);
          if (_localStream != null) {
            _localStream.dispose();
            _localStream = null;
          }

          RTCPeerConnection pc = _peerConnections[id];
          if (pc != null) {
            pc.close();
            _peerConnections.remove(id);
          }
          this._sessionId = null;
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;

      case 'bye':
        {
          var to = data['to'];

          if (_localStream != null) {
            _localStream.dispose();
            _localStream = null;
          }

          RTCPeerConnection pc = _peerConnections[to];
          if (pc != null) {
            pc.close();
            _peerConnections.remove(to);
          }

          this._sessionId = null;
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateBye);
          }
        }
        break;

      case 'keepalive':
        {
          print('keepaive');
        }
        break;
    }
  }

  /*
  * 结束会话
  * */
  void bye() {
    send('bye', {
      'session_id': this._sessionId,
      'from': this._selfId,
    });
  }

  /*
  * 创建peerconnection
  * */
  Future<RTCPeerConnection> _createPeerConnection(id) async {
    //获取本地媒体 并赋值给peerconnection

    _localStream = await createStream();
    RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);

    pc.addStream(_localStream);

    /*
    * 获得获选者
    * */
    pc.onIceCandidate = (candidate) {
      print('onIceCandidate');
      /*
      * 获取候选者后，向对方发送候选者
      * */
      send('candidate', {
        'to': id,
        'candidate': {
          'sdpMLineIndex': candidate.sdpMlineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        },
        'session_id': this._sessionId,
      });
    };

    pc.onIceConnectionState = (state) {};

    /*
    * 获取远端的媒体流
    * */
    pc.onAddStream = (stream) {
      if (this.onAddRemoteStream != null) this.onAddRemoteStream(stream);
    };

    /*
    * 移除远端的媒体流
    * */
    pc.onRemoveStream = (stream) {
      if (this.onRemoveRemoteStream != null) this.onRemoveRemoteStream(stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    return pc;
  }

  /*
  * 创建offer
  * */
  _createOffer(String id, RTCPeerConnection pc) async {
    try {
      RTCSessionDescription s = await pc.createOffer(_constraints);
      pc.setLocalDescription(s);
      //向远端发送自己的媒体信息
      send('offer', {
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  /*
  * 创建answer
  * */
  _createAnswer(String id, RTCPeerConnection pc) async {
    try {
      RTCSessionDescription s = await pc.createAnswer(_constraints);
      pc.setLocalDescription(s);
      /*
      * 回复answer
      * */
      send('answer', {
        'to': id,
        'description': {'sdp': s.sdp, 'type': s.type},
        'session_id': this._sessionId,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  /*
  * 消息发送
  * */
  void send(event, data) {
    data['type'] = event;
    JsonEncoder encoder = new JsonEncoder();
    if (_channel != null) _channel.sink.add(encoder.convert(data));
    print('send: ' + encoder.convert(data));
  }
}
