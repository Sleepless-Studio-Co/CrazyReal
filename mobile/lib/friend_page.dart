import 'package:flutter/material.dart';

class FriendPage extends StatelessWidget {
  const FriendPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Page'),
      ),
      body: const Center(
        child: Text('This is the friend page'),
      ),
    );
  }
}