import 'dart:collection';
import 'dart:io';

/// Singleton DataBuffer class to manage different types of queues (buffers).
class DataBuffer {
  // Private static instance (Singleton)
  static final DataBuffer _instance = DataBuffer._internal();

  // Private constructor
  DataBuffer._internal();

  // Factory constructor to provide access to the singleton
  factory DataBuffer() => _instance;

  // Private queues

  final Queue<dynamic> _intemp = Queue<dynamic>();
  final Queue<dynamic> _outtemp = Queue<dynamic>();
  final Queue<Map<String, dynamic>> _rootNodeBuffer =
      Queue<Map<String, dynamic>>();
  final Queue<Map<String, dynamic>> _connectPeerBuffer = Queue();
  final Queue<dynamic> _registerBuffer = Queue<dynamic>();
  final Queue<dynamic> _imBuffer = Queue<dynamic>();
  final Queue<dynamic> _rmBuffer = Queue<dynamic>();
  final Queue<dynamic> _cmBuffer = Queue<dynamic>();
  final Queue<dynamic> _inBuffer = Queue<dynamic>();
  final Queue<dynamic> _outBuffer = Queue<dynamic>();
  final Map<String, Socket> _clientSockets = <String, Socket>{};

  //===== client socket =====
  void addClientSocket(String node, Socket sock) {
    _clientSockets[node] = sock;
  }

  Socket? pullClientSocket(String node) {
    return _clientSockets.remove(node);
  }

  // ===== inBuffer =====
  void pushinBuffer(dynamic data) => _inBuffer.addLast(data);
  dynamic pullinBuffer() =>
      _inBuffer.isNotEmpty ? _inBuffer.removeFirst() : null;
  bool isinBufferEmpty() => _inBuffer.isEmpty;

  // ===== outBuffer =====
  void pushoutBuffer(dynamic data) => _outBuffer.addLast(data);
  dynamic pulloutBuffer() =>
      _outBuffer.isNotEmpty ? _outBuffer.removeFirst() : null;
  bool isoutBufferEmpty() => _outBuffer.isEmpty;

    // ===== cmBuffer  =====
  void pushcmBuffer(dynamic data) => _cmBuffer.addLast(data);
  dynamic pullcmBuffer() =>
      _cmBuffer.isNotEmpty ? _cmBuffer.removeFirst() : null;
  bool iscmBufferEmpty() => _cmBuffer.isEmpty;

  // ===== rmBuffer =====
  void pushrmBuffer(dynamic data) => _rmBuffer.addLast(data);
  dynamic pullrmBuffer() =>
      _rmBuffer.isNotEmpty ? _rmBuffer.removeFirst() : null;
  bool isrmBufferEmpty() => _rmBuffer.isEmpty;

  //===== imBuffer =====
  void pushimBuffer(dynamic data) => _imBuffer.addLast(data);
  dynamic pullimBuffer() =>
      _imBuffer.isNotEmpty ? _imBuffer.removeFirst() : null;
  bool isimBufferEmpty() => _imBuffer.isEmpty;

  // ==== Input Temporary Buffer ====

  void pushIntemp(dynamic data) => _intemp.addLast(data);

  dynamic pullIntemp() => _intemp.isNotEmpty ? _intemp.removeFirst() : null;

  bool isIntempEmpty() => _intemp.isEmpty;

  // ==== Output Temporary Buffer ====

  void pushOuttemp(dynamic data) => _outtemp.addLast(data);

  dynamic pullOuttemp() => _outtemp.isNotEmpty ? _outtemp.removeFirst() : null;

  bool isOuttempEmpty() => _outtemp.isEmpty;

  // ==== Root Node Buffer ====

  void pushRootNode(Map<String, dynamic> nodeData) =>
      _rootNodeBuffer.addLast(nodeData);

  dynamic pullRootNode() =>
      _rootNodeBuffer.isNotEmpty ? _rootNodeBuffer.removeFirst() : null;

  bool isRootNodeBufferEmpty() => _rootNodeBuffer.isEmpty;

  // ==== Peer Buffer ====
  void pushToPeerBuffer(
      String destinationNode_hashID, Map<String, dynamic> Message) {
    _connectPeerBuffer
        .add({"destination": destinationNode_hashID, "message": Message});
  }
  void pushToPeerBuffer1(Map<String, dynamic> CreateMessage) {
    _connectPeerBuffer.add({
      "destination": CreateMessage['destinationNode']['hashID'],
      "message": CreateMessage
    });
  }

  dynamic pullFromPeerBuffer() =>
      _connectPeerBuffer.isNotEmpty ? _connectPeerBuffer.removeFirst() : null;

  bool isPeerBufferEmpty() => _connectPeerBuffer.isEmpty;

  // ==== Register Buffer ====

  void pushToRegisterBuffer(dynamic destination) => _registerBuffer.addLast(destination);

  dynamic pullFromRegisterBuffer() =>
      _registerBuffer.isNotEmpty ? _registerBuffer.removeFirst() : null;

  bool isRegisterBufferEmpty() => _registerBuffer.isEmpty;

  // ==== IM Buffer ====
/*  void pushToIMBuffer(dynamic data) => _imbuffer.addLast(data);
  dynamic pullFromIMBuffer() =>
      _imbuffer.isNotEmpty ? _imbuffer.removeFirst() : null;

  // ==== RM Buffer ====
  void pushToRMBuffer(dynamic data) => _rmbuffer.addLast(data);
  dynamic pullFromRMBuffer() =>
      _rmbuffer.isNotEmpty ? _rmbuffer.removeFirst() : null;
  */
  // ==== Global Clear ====

  /// Clears all the buffers. Use with caution!
  void clearBuffers() {
    _intemp.clear();
    _outtemp.clear();
    _rootNodeBuffer.clear();
    _connectPeerBuffer.clear();
    _registerBuffer.clear();
     _imBuffer.clear();
    _rmBuffer.clear();
  }
}

// void main() {
//   // Access the singleton instance
//   var buffer = DataBuffer();

//   // Push a node into rootNodeBuffer
//   buffer.pushRootNode({"id": 1, "name": "RootNode1"});

//   // Push into peer buffer
//   buffer.pushToPeerBuffer("peer1", "message1");
//   buffer.pushToPeerBuffer("peer1", "message2");

//   // Pull data
//   print(buffer.pull()); // prints: Hello
//   print(buffer.pull()); // prints: World
//   print(buffer.pull()); // prints: null (empty now)

//   // Pull root node
//   var node = buffer.pullRootNode();
//   print(node); // prints: {id: 1, name: RootNode1}

//   // Pull peer message
//   print(buffer.pullFromPeerBuffer("peer1")); // prints: message1
//   print(buffer.pullFromPeerBuffer("peer1")); // prints: message2
//   print(buffer.pullFromPeerBuffer("peer1")); // prints: null (empty now)
// }
