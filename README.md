# beaker_bindings
The dart package for BeakerBrowser API related to hyper protocol. Works only with https://beakerbrowser.com/

# Supported API
- beaker.peersockets. WIP

# Usage Example

## Initialize topics
Initialize peersocket Topic before starting listeners:

```dart
  beaker.topicByName('sloboda');
```

You can add that line to your widget's initState() method. This will ensure that all channels that are used in your app with StreamBuilders are initialized before build() bethod is called.

This will initialize topic 'sloboda' and will populate beaker.channels Map with the reference to the Rx Stream.
It can be accessed like this:

```dart
beaker.channels['sloboda'].stream
```

All messages sent to 'sloboda' channel will be decoded by TextDecoder (JS native function) and then sent to jsonDecode. It will convert a string into Map<String, dynamic>.

## Using with StreamBuilder
You can use beaker.channels['some_name'].stream for StreamBuilders to build your UI:

```dart
StreamBuilder(
  initialData: [],
  stream: beaker.channels['sloboda'].stream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return _buildMainView(context, snapshot.data);
    }
  }),
```

## Sending messages to topics

Use this function to send your message to specific topic:
```dart
 void sendMessageToTopic(Map<String, dynamic> message, String topicName)
```

The function uses jsonEncode to encode your message into string, then uses TextEncoder (JS native function) to encode it before sending to hyper drive peersocket.

Now, any other listeners of 'topicName' who has the hyperdrive opened will get a new message into channel's stream.

## Sending messages to specific peer

```dart
List sendMessageToPeer({String peerId, Map<String, dynamic> message, String topicName})
```

The method returns a list. First element is a UUID. A unique key generated just for your message. It can be stored and used later to acknowledge that the receiving peer responded to your message. The second element is the Future.

*The behaviour described above will be changed*

Example of using this method to store the UUID.

```dart
RaisedButton(
  child: Text("Send to $peerId"),
  onPressed: () async {
    var result = beaker.sendMessageToPeer(
        peerId: peerId,
        topicName: 'sloboda',
        message: {"hello": "World"});
    var uuid = result[0];
    setState(() {
      outcoming[uuid] = false; // message sent but response not yet received (true)
      print("set state after getting response for: ${outcoming}");
    });
    Map response = await result[1];
  },
);
```

Now you can use UUID to understand whether receiving peer responded to your message:
```dart
@override
void initState() {
  beaker.topicByName('sloboda');
  beaker.channels['sloboda'].stream.listen((message) {
    var uuid = message["uuid"];
    if (outcoming[uuid] != null) {
      print("Received intercom message: $message ");
      outcoming.removeWhere((key, value) => key == uuid); // remove outcoming UUIDs as the response was received.
    } else {
      incoming[uuid] = message; // save incoming request UUIDs
    }
  });
  super.initState();
}
```

## Get list of connected peers
Listen to stream:

```dart
beaker.joinedChannel.stream
```

To get a message when someone opens your hyperdrive link. You can use Set() to store peerIds in the stream listener.


