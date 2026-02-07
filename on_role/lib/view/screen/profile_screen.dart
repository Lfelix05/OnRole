import 'package:flutter/material.dart';
import 'package:on_role/view/screen/background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children:[
          Background(),
          Center(
            child: Text(
              'Tela de Perfil',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}