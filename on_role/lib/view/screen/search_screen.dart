import 'package:flutter/material.dart';
import 'package:on_role/view/screen/background.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children:[
          Background(),
          Center(
            child: Text(
              'Tela de Busca',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ],
      )
    );
  }
}