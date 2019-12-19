import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rtc_demo/rtc_signaling.dart';
import 'package:flutter_webrtc/rtc_video_view.dart';

class P2PDemo extends StatefulWidget {
  final String url;

  P2PDemo({Key key, @required this.url}) : super(key: key);

  @override
  _P2PDemoState createState() => _P2PDemoState(serverurl: url);
}

class _P2PDemoState extends State<P2PDemo> {
  final String serverurl;

  _P2PDemoState({Key key, @required this.serverurl});

  // rtc 信令对象
  RTCSignaling _signaling;

  // 本地设备名称
  String _displayName =
      '${Platform.localeName.substring(0, 2)} + ( ${Platform.operatingSystem} )';
  // 房间内的
  List<dynamic> _peers;
  var _selfId;
  // 本地媒体视频窗口
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  // 对端媒体视频窗口
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _inCalling = false;

  // 初始化
  @override
  void initState() {
    super.initState();
    initRenderers();
    _connect();
  }

  // 懒加载本地和对端渲染窗口
  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // 销毁操作
  @override
  void deactivate() {
    super.deactivate();
    if (_signaling != null) _signaling.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  // 创建联系
  void _connect() async {
    // 初始化信令
    if (_signaling == null) {
      _signaling = RTCSignaling(url: serverurl, displayName: _displayName);
      // 信令状态回调
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
            break;
          case SignalingState.CallStateInvite:
            break;
          case SignalingState.CallStateConnected:
            break;

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

      // 移除远端媒体
      _signaling.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });

      // socket 进行连接
      _signaling.connect();
    }
  }

  // 邀请对方
  _invitePeer(peerId) async {
    _signaling?.invite(peerId);
  }
  // 挂断
  _hangUp() {
    _signaling?.bye();
  }
  // 切换前后摄像头
  _switchCamera() {
    _signaling.switchCamera();
    _localRenderer.mirror = true;
  }
  // 初始化 列表
  _buildRow(context, peer) {
    bool self = (peer['id'] == _selfId);

    return ListBody(
      children: <Widget>[
        ListTile(
          title: Text(self
              ? peer['name'] + 'self'
              : peer['name'] + '${peer['user_agent']}]'),
          trailing: SizedBox(
            width: 100.0,
            child: IconButton(
              icon: Icon(Icons.videocam),
              onPressed: () => _invitePeer(peer['id']),
            ),
          ),
        ),
        Divider()
      ],
    );
  }

  // 构建当前视图
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Call sample'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 200.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FloatingActionButton(
                    heroTag: 1,
                    onPressed: _switchCamera,
                    child: Icon(Icons.switch_camera),
                  ),
                  FloatingActionButton(
                    heroTag: 2,
                    onPressed: _hangUp,
                    child: Icon(Icons.call_end),
                    backgroundColor: Colors.deepOrange,
                  )
                ],
              ),
            )
          : null,
      body: _inCalling
          ? OrientationBuilder(
              builder: (context, orientation) {
                return Container(
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            margin: EdgeInsets.all(0),
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            child: RTCVideoView(_remoteRenderer),
                            decoration: BoxDecoration(color: Colors.grey),
                          )),
                      Positioned(
                          right: 20.0,
                          top: 20.0,
                          child: Container(
                            width: orientation == Orientation.portrait
                                ? 90.0
                                : 120.0,
                            height: orientation == Orientation.portrait
                                ? 120.0
                                : 90.0,
                            child: RTCVideoView(_localRenderer),
                            decoration: BoxDecoration(color: Colors.black54),
                          ))
                    ],
                  ),
                );
              },
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.all(0.0),
              itemCount: (_peers != null ? _peers.length : 0),
              itemBuilder: (context, i) {
                return _buildRow(context, _peers[i]);
              }),
    );
  }
}
