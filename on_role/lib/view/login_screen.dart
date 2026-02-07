import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1A237E),
                  Color(0xFF424242),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            opacity: const AlwaysStoppedAnimation(0.2),
          ),
          Center(child:
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 30.0,
                  right: 30.0,
                  top: 24.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Tela de Login',
                      style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24.0),
                    Card(
                      color: const Color.fromARGB(255, 223, 227, 255)
                          .withOpacity(0.9),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TextFormField(
                              decoration: InputDecoration(labelText: 'Email', 
                              helperStyle: TextStyle(fontWeight: FontWeight.bold, 
                              color: Colors.white), icon: Icon(Icons.email), 
                              contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0), 
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
                            ),
                            SizedBox(height: 20.0),
                            TextFormField(
                              decoration: InputDecoration(labelText: 'Senha',
                              helperStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), 
                              icon: Icon(Icons.lock), 
                              contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0), 
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
                              obscureText: true,
                            ),
                            SizedBox(height: 30.0),
                            ElevatedButton(
                              onPressed: () {
                                // Lógica de autenticação aqui
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                minimumSize: Size(200.0, 50.0),
                              ),
                              child: Text('Entrar', style: TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}