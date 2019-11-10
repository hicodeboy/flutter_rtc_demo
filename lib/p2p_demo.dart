import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class P2PDemo extends StatefulWidget {
  @override
  _P2PDemoState createState() => _P2PDemoState();
}

class _P2PDemoState extends State<P2PDemo> {
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
