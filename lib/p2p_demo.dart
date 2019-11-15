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
