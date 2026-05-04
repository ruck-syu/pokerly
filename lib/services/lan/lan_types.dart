import '../../models/game_state.dart';

enum HostEventType { playerJoined, playerDisconnected, playerAction }

class LanPlayerInfo {
  const LanPlayerInfo({
    required this.id,
    required this.name,
    required this.isHost,
    this.connected = true,
  });

  final String id;
  final String name;
  final bool isHost;
  final bool connected;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
        'connected': connected,
      };

  factory LanPlayerInfo.fromJson(Map<String, dynamic> json) {
    return LanPlayerInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: json['isHost'] as bool? ?? false,
      connected: json['connected'] as bool? ?? true,
    );
  }
}

class HostEvent {
  const HostEvent({
    required this.type,
    this.playerId,
    this.action,
    this.amount,
    this.players = const [],
  });

  final HostEventType type;
  final String? playerId;
  final String? action;
  final int? amount;
  final List<LanPlayerInfo> players;
}

abstract class HostSession {
  String get hostPlayerId;
  int get port;
  String? get hostIp;
  List<LanPlayerInfo> get players;
  Stream<HostEvent> get events;
  Future<void> broadcast(Map<String, dynamic> message);
  Future<void> sendTo(String playerId, Map<String, dynamic> message);
  Future<void> close();
}

abstract class ClientSession {
  String get playerId;
  List<LanPlayerInfo> get players;
  Stream<Map<String, dynamic>> get messages;
  Future<void> send(Map<String, dynamic> message);
  Future<void> close();
}

abstract class LanTransport {
  bool get supported;
  Future<HostSession> hostGame({required String hostName, int port = 4040});
  Future<ClientSession> joinGame({
    required String hostIp,
    required String playerName,
    int port = 4040,
  });
  Future<String?> localIpv4();
}

abstract class LanRole {
  static const none = 'none';
  static const host = 'host';
  static const client = 'client';
}

class LanStartPayload {
  const LanStartPayload({
    required this.state,
    required this.localPlayerId,
  });

  final GameState state;
  final String localPlayerId;
}
