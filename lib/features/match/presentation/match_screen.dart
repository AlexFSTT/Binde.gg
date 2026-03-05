import 'package:flutter/material.dart';

class MatchScreen extends StatelessWidget {
  final String matchId;
  const MatchScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Match: $matchId')),
    );
  }
}
