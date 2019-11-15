import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rtc_demo/rtc_signaling.dart';
import 'package:flutter_webrtc/rtc_video_view.dart';

class P2PDemo extends StatefulWidget {
  final String url;

  P2PDemo({Key key, @required this.url}) : super(key: key);

  @override
  _P2PDemoState createState() => _P2PDemoState();
}

class _P2PDemoState extends State<P2PDemo> {
  final String serverUrl;

  _P2PDemoState({Key key, @required this.serverUrl});

  // 信令对象
  RTCSignaling _signaling;

  // 本地设备名称
  String _displayName =
      '${Platform.localeName.substring(0, 2)} + (${Platform.operatingSystem} )';

  // 房间内的peer对象
  List<dynamic> _peers;

  var _selfId;

  // 本地媒体渲染对象
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  // 对端媒体渲染对象
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  // 是否处于通话状态
  bool _inCalling = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _connect();
  }

  // 懒加载本地和对端渲染窗口
  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // 连接socket
  void _connect() async {
    if (_signaling == null) {
      _signaling = RTCSignaling(url: serverUrl, display: _displayName);

      // 信令状态的回调
      _signaling.onStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.CallStateNew:
            setState(() {
              _inCalling = true;
            });
            break;
          case SignalingState.CallStateBye:
            setState(() {
              _localRenderer.srcObject = null;
              _remoteRenderer.srcObject = null;
              _inCalling = false;
            });
            break;
          case SignalingState.CallStateRinging:
          case SignalingState.CallStateInvite:
          case SignalingState.CallStateConnected:
          case SignalingState.ConnectionOpen:
            break;
          case SignalingState.ConnectionClosed:
            break;
          case SignalingState.ConnectionError:
            break;
        }
      };

      // 更新房间人员列表
      _signaling.onPeersUpdate = ((event) {
        setState(() {
          _selfId = event['self'];
          _peers = event['peers'];
        });
      });

      // 设置本地媒体
      _signaling.onLocalStream = ((stream) {
        _localRenderer.srcObject = stream;
      });

      // 设置远端媒体
      _signaling.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
      });

      // socket 进行连接
      _signaling.connect();
    }
  }

  Widget _buildRow(context, peer) {
    return ListBody(
      children: <Widget>[
        ListTile(
          title: Text(peer),
          trailing: SizedBox(
            width: 100,
            child: IconButton(
                icon: Icon(Icons.videocam),
                onPressed: () {
                  print('呼叫对方');
                }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Call Sample'),
      ),
      body: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.all(1),
          itemCount: 5,
          itemBuilder: (context, i) {
            return _buildRow(context, '测试');
          }),
    );
  }
}
