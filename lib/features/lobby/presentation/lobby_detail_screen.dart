import 'package:flutter/material.dart';

class LobbyDetailScreen extends StatelessWidget {
  final String lobbyId;
  const LobbyDetailScreen({super.key, required this.lobbyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Lobby: $lobbyId')),
    );
  }
}
