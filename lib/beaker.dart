@JS("beaker")
library beaker;

import 'dart:async';
import 'dart:convert';
import 'dart:js';

import 'package:js/js.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

external PeerSockets get peersockets;

@JS()
class PeerSockets {
  external Function get watch;

  external Function get join;
}

@JS()
class Event {
  external String get peerId;

  external String get message;
}

@JS()
class Topic {
  external Function send(String peerId, String message);

  external void addEventListener(
      String eventName, Function callback(Event event));
}

@JS()
class PeerEvents {
  external void addEventListener(
      String eventName, Function callback(PeerId peerId));
}

@JS()
class PeerId {
  external String get peerId;
}

class Beaker {
  Beaker() {
    PeerSockets socket = peersockets;
    PeerEvents events = socket.watch();
    events.addEventListener('join', allowInterop((peerId) {
      peers.add(peerId.peerId);
      joinedChannel.add(peerId.peerId);
    }));

    events.addEventListener('leave', allowInterop((peerId) {
      peers.remove(peerId.peerId);
      leaveChannel.add(peerId.peerId);
    }));
  }

  BehaviorSubject joinedChannel = BehaviorSubject();
  BehaviorSubject leaveChannel = BehaviorSubject();

  List<String> get allPeers {
    return peers.toList();
  }

  static bool hasBeakerAPI() {
    return !!context["beaker"];
  }

  var _jsTextEncoder = new JsObject(context['TextEncoder']);
  var _jsTextDecoder = new JsObject(context['TextDecoder']);

  Set<String> peers = Set();
  Map<String, Topic> topics = {};
  Map<String, BehaviorSubject> channels = {};

  Topic topicByName(String name) {
    if (topics[name] == null) {
      Topic topic = peersockets.join(name);
      channels[name] = BehaviorSubject();
      topic.addEventListener('message', allowInterop((event) {
        Map decoded = _decodeJson(event.message);
        decoded["fromPeerId"] = event.peerId;
        print("Decoded topic $name with message: $decoded");
        channels[name].add(decoded);
      }));
      topics[name] = topic;
    }
    return topics[name];
  }

  Map<String, dynamic> _decodeJson(String message) {
    return jsonDecode(_jsTextDecoder.callMethod("decode", [message]));
  }

  String _encodeJson(Map message) {
    return _jsTextEncoder
        .callMethod("encode", [jsonEncode(message).toString()]);
  }

  List sendMessageToPeer(
      {String peerId, Map<String, dynamic> message, String topicName}) {
    var id = new Uuid().v1();
    Map messageWithId = {
      ...message,
      ...{"uuid": id}
    };
    Completer completer = Completer();
    var encoded = _encodeJson(messageWithId);
    var topic = topicByName(topicName);
    var listener = channels[topicName]
        .stream
        .where((decodedMessage) => decodedMessage["uuid"] == id);

    listener.listen((decodedMessage) {
      print("Received response for the uuid: $id : $decodedMessage");
      completer.complete(decodedMessage);
    });
    print("Sending targeted message to: $peerId and message: $messageWithId");
    topic.send(peerId, encoded);
    return [id, completer.future];
  }

  void sendMessageToTopic(Map<String, dynamic> message, String topicName) {
    peers.forEach((String peer) {
      var encoded = _encodeJson(message);
      print("sending topic: $topicName to: $peer with message: $message");
      topicByName(topicName).send(peer, encoded);
    });
  }
}
