import 'package:nodeid/nodeid.dart';

void main() {
  LocalNodeID localnd = LocalNodeID();
  print(localnd.nodeID);
  print(localnd.pubKey);
  print(localnd.pvtKey);
  print(localnd.sign);
  print(localnd.verify);
}
