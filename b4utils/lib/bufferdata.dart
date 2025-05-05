import 'dart:collection';

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
  final Queue<Map<String, dynamic>> _rootNodeBuffer = Queue<Map<String, dynamic>>();
  final Queue<Map<String, dynamic>> _connectPeerBuffer = Queue(); 
  final Queue<dynamic> _registerBuffer = Queue<dynamic>();

 
  // ==== Input Temporary Buffer ====

  void pushIntemp(dynamic data) => _intemp.addLast(data);

  dynamic pullIntemp() => _intemp.isNotEmpty ? _intemp.removeFirst() : null;

  bool isIntempEmpty() => _intemp.isEmpty;

  // ==== Output Temporary Buffer ====

  void pushOuttemp(dynamic data) => _outtemp.addLast(data);

  dynamic pullOuttemp() => _outtemp.isNotEmpty ? _outtemp.removeFirst() : null;

  bool isOuttempEmpty() => _outtemp.isEmpty;

  // ==== Root Node Buffer ====

  void pushRootNode(Map<String, dynamic> nodeData) => _rootNodeBuffer.addLast (nodeData);

  dynamic pullRootNode() =>
      _rootNodeBuffer.isNotEmpty ? _rootNodeBuffer.removeFirst() : null;

  bool isRootNodeBufferEmpty() => _rootNodeBuffer.isEmpty;

  // ==== Peer Buffer ====

  void pushToPeerBuffer(Map<String, dynamic> destinationNode, Map<String, dynamic> CreateMessage){
    _connectPeerBuffer.add({"destination": destinationNode['hashID'], "message": CreateMessage});
  }

  dynamic pullFromPeerBuffer() => _connectPeerBuffer.isNotEmpty ? _connectPeerBuffer.removeFirst() : null;
 
  bool isPeerBufferEmpty() => _connectPeerBuffer.isEmpty;

  // ==== Register Buffer ====

  void pushToRegisterBuffer(dynamic data) => _registerBuffer.addLast(data);

  dynamic pullFromRegisterBuffer() => _registerBuffer.isNotEmpty ? _registerBuffer.removeFirst() : null;

  bool isRegisterBufferEmpty() => _registerBuffer.isEmpty;

  // ==== Global Clear ====

  /// Clears all the buffers. Use with caution!
  void clearBuffers() {
    _intemp.clear();
    _outtemp.clear();
    _rootNodeBuffer.clear();
    _connectPeerBuffer.clear();
    _registerBuffer.clear();
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
