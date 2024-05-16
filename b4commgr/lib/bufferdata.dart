import 'dart:collection';

class DataBuffer {
  // Private static instance of the buffer
  static final DataBuffer _instance = DataBuffer._internal();

  // Queue to hold the data
  final Queue<dynamic> _buffer = Queue<dynamic>();

  // Private constructor
  DataBuffer._internal();

  // Factory constructor to access the singleton instance
  factory DataBuffer() {
    return _instance;
  }

  // Method to add data to the buffer
  void push(dynamic data) {
    _buffer.addLast(data);
  }

  // Method to pull data from the buffer
  dynamic pull() {
    return _buffer.isEmpty ? null : _buffer.removeFirst();
  }
}
