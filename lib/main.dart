import 'package:flutter/material.dart';
import 'package:flutter_rtc_demo/p2p_demo.dart';
import 'package:flutter_rtc_demo/rtc_signaling.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter WebRTC Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _entryRoom() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) =>
                P2PDemo(url: 'ws://www.supercodeboy.com:7080')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Center(
          child: RaisedButton(
            onPressed: _entryRoom,
            child: Text('进入房间'),
          ),
        ),
      ),
    );
  }
}
