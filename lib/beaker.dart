@JS("beaker")
library beaker;

import 'dart:convert';
import 'dart:js';

import 'package:js/js.dart';
import 'package:rxdart/rxdart.dart';

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
  static bool hasBeakerAPI() {
    return !!context["beaker"];
  }

  Set<String> peers = Set();
  Map<String, Topic> topics = {};
  Map<String, BehaviorSubject> channels = {};

  Beaker() {
    PeerSockets socket = peersockets;
    PeerEvents events = socket.watch();
    events.addEventListener('join', allowInterop((peerId) {
      print('registered peer id: ${peerId.peerId}');
      peers.add(peerId.peerId);
    }));

    events.addEventListener('leave', allowInterop((peerId) {
      print('peer id left: ${peerId.peerId}');
      peers.remove(peerId.peerId);
    }));
  }

  Topic topicByName(String name) {
    return _createTopic(name);
  }

  Topic _createTopic(String name) {
    if (topics[name] == null) {
      Topic topic = peersockets.join(name);
      channels[name] = BehaviorSubject();
      topic.addEventListener('message', allowInterop((event) {
        print('received message from ${event.peerId}');
        var another = new JsObject(context['TextDecoder']);
        var result = another.callMethod("decode", [event.message]);
        print("received payload: ${jsonDecode(result)}");
        channels[name].add(jsonDecode(result));
      }));

      topics.addEntries([MapEntry(name, topic)]);
    }

    return topics[name];
  }

  void sendMessageToTopic(Map<String, dynamic> message, String topicName) {
    var topic = topicByName(topicName);
    peers.forEach((String peer) {
      print("sending to: $peer");
      var another = new JsObject(context['TextEncoder']);
      var result =
          another.callMethod("encode", [jsonEncode(message).toString()]);
      topic.send(peer, result);
    });
  }
}
