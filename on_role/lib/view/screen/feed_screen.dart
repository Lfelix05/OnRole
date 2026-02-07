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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: SizedBox(
        width: double.infinity,
        child: Text('OnRolê', style: TextStyle(fontSize: 24, fontFamily: 'Cascadia Code', color: Colors.white), textAlign: TextAlign.center)),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
      body: Stack(alignment: AlignmentDirectional(0, 0),
      children: [
        Background(),
        CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 4.0),
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 223, 227, 255).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16.0,
                                    backgroundColor: Colors.deepPurple,
                                    child: IconButton(onPressed: () {}, icon: Icon(Icons.person, color: Colors.white, size: 16.0)),
                                  ),
                                  SizedBox(width: 2.0),
                                  TextButton(onPressed: () {}, child: Text('Usuário ${index + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black))),
                                ],
                              ),
                            ),
                            Text('Postagem #${index + 1}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8.0),
                            Text('Conteúdo da postagem número ${index + 1}.'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                childCount: 20,
              ),
            ),
          ],
        )
      ],
      )
    );
  }
}