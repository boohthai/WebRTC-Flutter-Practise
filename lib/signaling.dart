import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef void StreamStateCallback(MediaStream stream);

class Signaling {
  Map<String, dynamic> configuration = {
    "iceServers": [
      {"url": "stun:stun.l.google.com:19302"},
    ]
  };
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String roomId = '';
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;
  Future<String> createRoom(RTCVideoRenderer remoteRenderer) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('room').doc();
    print('Create PeerConnection with configuration: $configuration');
    peerConnection = await createPeerConnection(configuration);
    registerPeerConnectionListeners();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    var callerCandidatesCollection = roomRef.collection('callerCandidates');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('Got candidate: ${candidate.toMap()}');
      callerCandidatesCollection.add(candidate.toMap());
    };
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};
    await roomRef.set(roomWithOffer);
    roomId = roomRef.id;
    currentRoomText = 'Current room is $roomId - You are the caller!';
    //room created

    peerConnection?.onTrack = (RTCTrackEvent event) {
      print('Got remote track: ${event.streams[0]}');
      event.streams[0].getTracks().forEach((track) {
        print('Add  a track to the remoteStream $track');
        remoteStream?.addTrack(track);
      });
    };
    roomRef.snapshots().listen((snapshot) async {
      print('Got updated room: ${snapshot.data()}');
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      if (peerConnection?.getRemoteDescription() != null &&
          data['answer'] != null) {
        var answer = RTCSessionDescription(
            data['answer']['sdp'], data['answer']['type']);
        print("Someone tried to connect");
        await peerConnection?.setRemoteDescription(answer);
      }
    });

    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      snapshot.docChanges.forEach((change) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          print('Got new remote ICE candidate: ${jsonEncode(data)}');
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      });
    });
    return roomId;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteVideo) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('room').doc('$roomId');
    var roomSnapshot = await roomRef.get();
    print('Got room ${roomSnapshot.exists}');
    if (roomSnapshot.exists) {
      print('Create PeerConnection with configuration: $configuration');
      peerConnection = await createPeerConnection(configuration);
      registerPeerConnectionListeners();
      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });
      var calleeCandidatesCollection = roomRef.collection('calleeCandidates');
      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate == null) {
          print('onIceCandidate: complete');
          return;
        }
        print('onIceCandidate: ${candidate.toMap()}');
        calleeCandidatesCollection.add(candidate.toMap());
      };
      peerConnection?.onTrack = (RTCTrackEvent event) {
        print('Got remote track: ${event.streams[0]}');
        event.streams[0].getTracks().forEach((track) {
          print('Add a track to the remoteStream: $track');
          remoteStream?.addTrack(track);
        });
      };
      var data = roomSnapshot.data() as Map<String, dynamic>;
      print('Got offer $data');
      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']));
      var answer = await peerConnection!.createAnswer();
      print('Created answer $answer');
      await peerConnection!.setLocalDescription(answer);
      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      };
      await roomRef.update(roomWithAnswer);

      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        snapshot.docChanges.forEach((document) {
          var data = document.doc.data() as Map<String, dynamic>;
          print(data);
          print('Got new remote ICE candidate: $data');
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        });
      });
    }
  }

  Future<void> openUserMedia(
    RTCVideoRenderer localVideo,
    RTCVideoRenderer remoteVideo,
  ) async {
    var stream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': false,
    });
    localVideo.srcObject = stream;
    localStream = stream;
    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    List<MediaStreamTrack> tracks = localVideo.srcObject!.getTracks();
    tracks.forEach((track) {
      track.stop();
    });
    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
    }
    if (peerConnection != null) peerConnection!.close();
    //if (roomId != null) {
    print(roomId);
    var db = FirebaseFirestore.instance;
    db.collection('room').doc(roomId).delete();
    localStream!.dispose();
    remoteStream?.dispose();
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering stata changed: $state');
    };
    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };

    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE connection state change: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      print("Add remote stream");
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
    };
  }
}
