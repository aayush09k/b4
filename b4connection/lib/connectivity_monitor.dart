import 'dart:async';
import 'dart:io';

class ConnectivityMonitor {
  late final Timer _timer;
  List<NetworkInterface>? _lastInterfaces;
  final _controller = StreamController<List<NetworkInterface>>.broadcast();

  Stream<List<NetworkInterface>> get onConnectivityChanged => _controller.stream;

  ConnectivityMonitor({Duration checkInterval = const Duration(seconds: 1)}) {
    _timer = Timer.periodic(checkInterval, (timer) async {
      _checkInterfaces();
    });
  }

  Future<void> _checkInterfaces() async {
    List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.any,
    );

    if (_lastInterfaces == null || _hasChanges(interfaces, _lastInterfaces!)) {
      _controller.add(interfaces);
    }

    _lastInterfaces = interfaces;
  }

  bool _hasChanges(List<NetworkInterface> current, List<NetworkInterface> last) {
    // Check if the count of network interfaces has changed
    if (current.length != last.length) {
      return true;
    }

    // Create maps from interface names to their IP addresses for easy comparison
    var currentMap = {for (var i in current) i.name: i.addresses.map((addr) => addr.address).toSet()};
    var lastMap = {for (var i in last) i.name: i.addresses.map((addr) => addr.address).toSet()};

    // Check if there's any interface name that doesn't exist in both lists
    if (Set.from(currentMap.keys).difference(Set.from(lastMap.keys)).isNotEmpty ||
        Set.from(lastMap.keys).difference(Set.from(currentMap.keys)).isNotEmpty) {
      return true;
    }

    // For each interface, check if the IP addresses are exactly the same
    for (var interfaceName in currentMap.keys) {
      var currentAddresses = currentMap[interfaceName]!;
      var lastAddresses = lastMap[interfaceName]!;

      // Check for differences in the addresses
      if (currentAddresses.length != lastAddresses.length ||
          currentAddresses.difference(lastAddresses).isNotEmpty ||
          lastAddresses.difference(currentAddresses).isNotEmpty) {
        return true;
      }
    }

    // If none of the above checks found a difference, return false
    return false;
  }


  void dispose() {
    _timer.cancel();
    _controller.close();

  }
}
