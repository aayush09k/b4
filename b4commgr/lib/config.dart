class TimingConstants {
  // static const int registerBufferRetrySeconds = 30;
  // static const int peerBufferRetrySeconds = 35;
  // static const int processIntempMinutes = 1;
  // static const int processOuttempMinutes = 1;
  // static const int rootNodeBufferRetrySeconds = 5;
  
  // Timer durations
  static const Duration registerBufferRetryInterval = Duration(seconds: 30);
  static const Duration peerBufferRetryInterval = Duration(seconds: 35);
  static const Duration rootNodeBufferRetryInterval = Duration(seconds: 30);
  static const Duration processIntempInterval = Duration(minutes: 1);
  static const Duration processOuttempInterval = Duration(minutes: 1);

  
  static const Duration sendMessageViaRelayDelay = Duration(seconds: 2);

  // Timeout for socket connection
  static const Duration proxySocketTimeout = Duration(seconds: 2);
  
}