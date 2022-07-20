import 'dart:convert';
//import 'dart:html';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:webrtc/signaling.dart';
import 'firebase_options.dart';
//import './customCamera.js';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Signaling signaling = Signaling();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? roomId;
  TextEditingController textEditingController = TextEditingController(text: '');

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    signaling.onAddRemoteStream = ((stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Video Conference Demo"),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 8,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: () {
                        signaling.openUserMedia(
                            _localRenderer, _remoteRenderer);
                      },
                      child: Text("Allow camera and microphone")),
                  SizedBox(
                    width: 8,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      roomId = await signaling.createRoom(_remoteRenderer);
                      textEditingController.text = roomId!;
                      setState(() {});
                    },
                    child: Text("Create room"),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      signaling.joinRoom(
                          textEditingController.text, _remoteRenderer);
                    },
                    child: Text('Join room'),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // signaling.hangUp(_localRenderer);
                    },
                    child: Text("Hangup"),
                  )
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                        child: Container(
                      color: Colors.teal[100],
                      child: RTCVideoView(_localRenderer, mirror: true),
                    )),
                    Expanded(
                        child: Container(
                            color: Colors.green[300],
                            child: RTCVideoView(_remoteRenderer))),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Join the following Room: "),
                  Flexible(
                    child: TextFormField(
                      controller: textEditingController,
                    ),
                  )
                ],
              ),
            ),
          ],
        ));
  }
}
