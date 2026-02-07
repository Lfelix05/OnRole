import 'package:flutter/material.dart';
import 'package:on_role/view/screen/background.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children:[
          Background(),
          Center(
            child: Text(
              'Tela de Mapa',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}