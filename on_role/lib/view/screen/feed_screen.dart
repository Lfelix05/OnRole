import 'package:flutter/material.dart';
import 'package:on_role/view/screen/background.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(alignment: AlignmentDirectional(0, 0),
      children: [
        Background(),
        Card(
          color: const Color.fromARGB(255, 223, 227, 255),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bem-vindo ao Feed!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16.0),
                Text(
                  'Aqui você verá as últimas novidades e eventos.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        )
      ],
      )
    );
  }
}