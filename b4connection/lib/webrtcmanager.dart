import 'dart:convert';
import 'dart:html'as html;
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'dart:async';
import 'b4connection.dart';

class WebRTCManager{
//declaration of variables
  bool offer = false;
  String msg='hi i have sent you this message from my macbook';
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();//It is used to render video frames from a media stream.
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();//In the context of WebRTC, it's commonly used to display video streams - both the local stream (from your device's camera) and the remote stream (from the remote peer).
  RTCDataChannelInit data= RTCDataChannelInit();
  RTCDataChannel? dataChannel;
  List applecandidate =[];
  RTCDataChannel? remotechannel;
  String? sessionoffer;

  void initiatingWebrtc(){
    _initRenderers();
  }


  Future<void> _initRenderers() async {
    localRenderer.initialize();
    remoteRenderer.initialize();
  }
  // function for creating instance and initiate the RTCpeerconnection.
  Future<void> PeerConnection() async {

    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
    };

    print('server start');
    localStream = await getusermedia(); // to get the local video and audio data. its necessary for getting ice candidates.
    RTCPeerConnection pc = await createPeerConnection(configuration,offerSdpConstraints); //instance of peerconnection.
    pc.addStream(localStream!);


    RTCDataChannel dataChannel = await pc.createDataChannel(
        "macbook_channel", data); //data channel instance created once.

    print(dataChannel);

    //All event listeners are coded here . they need to be run once . Hence after each change they will be triggered.

    //for receiving message
    pc.onDataChannel=(h){
      remotechannel=h;
      dataChannel.send(RTCDataChannelMessage(msg));
      print('channel is received:${h.label}');
      h.onMessage=(e){
        print('received:${e.text}');
      };
    };

    //data channel state
    dataChannel.onDataChannelState = (state) {
      print(state.toString());
    };

    //for getting ice candidates
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        applecandidate.add(e.candidate);
      }
      print(json.encode({
        'candidate': e.candidate.toString(),
        'sdpMid': e.sdpMid.toString(),
        'sdpMlineIndex': e.sdpMLineIndex,
      }));
    };

    //for ice connection state
    pc.onIceConnectionState = (e) {
      print(e);
    };

    //for RTCpeerconnection state
    pc.onConnectionState=(s){
      print(s);
    };

    //for icegatheringstate
    pc.onIceGatheringState = (e) {
      print(e.name);
    };

    //for capturing incoming stream
    pc.onAddStream = (stream) {
      print('addStream:' + stream.id);
      remoteRenderer.srcObject = stream;
    };

    peerConnection = pc;

  }

  //function for capturing user media.
  Future<MediaStream> getusermedia() async {

    final Map<String, dynamic> constraints = {
      'audio': false,
      'video': {'facingMode': 'user'},
    };

    MediaStream stream = await mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = stream;
    RTCVideoView(localRenderer, mirror: true);
    return stream;
  }

  //for creating sdp offer.
  Future<void> createoffer() async {
    RTCSessionDescription description = await peerConnection!.createOffer({'offerToReceiveVideo':1});
    var session = parse(description.sdp.toString());
    offer = true;
    peerConnection?.setLocalDescription(description);// To set the sdp as local description.
    sessionoffer=json.encode(session);
    print(json.encode(session));
    //for downloading the offer file .
    /*var filename='offer_from_mac';
    final bytes = Uint8List.fromList(utf8.encode(json.encode(session)));
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download",filename)
      ..click();
    html.Url.revokeObjectUrl(url);*/

  }

  //for creation of answer.
  Future<void> createanswer() async {
    RTCSessionDescription description = await peerConnection!.createAnswer({'offerToReceiveVideo':1});
    var session = parse(description.sdp.toString());
    peerConnection?.setLocalDescription(description); // To set the local description.

    //To download the answer.
    var filename='answer_from_mac';
    final bytes = Uint8List.fromList(utf8.encode(json.encode(session)));
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download",filename)
      ..click();
    html.Url.revokeObjectUrl(url);

  }

  //To set the remote peer sdp as remote description . it tells us that what remote peer is capable of .
  Future<void> setRemoteDescription(String jsonString) async {
    dynamic session = await jsonDecode('$jsonString');
    String sdp = write(session, null);
    RTCSessionDescription description = RTCSessionDescription(sdp, offer ? 'answer' : 'offer');//constructor call
    print(description.toMap());
    await peerConnection!.setRemoteDescription(description);
  }

  //To add the candidate to the my instance of peerconnection.
  Future<void> setCandidate(String jsonString) async {
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    RTCIceCandidate candidate =RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMLineIndex']);
    await peerConnection!.addCandidate(candidate);
  }


  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
  }

  // for close connection.
  void closeconnection(){
    peerConnection!.close();
  }

}