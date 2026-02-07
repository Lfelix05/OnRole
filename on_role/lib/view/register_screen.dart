import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Registrar'),
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
          Center(
            child:
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
                      'Tela de Registro',
                      style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24.0),
                    Card(
                      color: const Color.fromARGB(255, 223, 227, 255)
                          .withOpacity(0.9),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Campos de registro (exemplo)
                            TextFormField(
                              decoration:
                                  InputDecoration(labelText: 'Nome',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                                  icon: Icon(Icons.person)),
                            ),
                            SizedBox(height: 16.0),

                            TextFormField(
                              decoration:
                                  InputDecoration(labelText: 'Nome de Usuário',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                                  icon: Icon(Icons.account_circle)),
                            ),
                            SizedBox(height: 16.0),
                            TextFormField(
                              decoration:
                                  InputDecoration(labelText: 'Email',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                                  icon: Icon(Icons.email)),
                            ),
                            SizedBox(height: 16.0),
                            TextFormField(
                              decoration:
                                  InputDecoration(labelText: 'Senha',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                                  icon: Icon(Icons.lock)),
                              obscureText: true,
                            ),
                            SizedBox(height: 24.0),
                            ElevatedButton(
                              onPressed: () {
                                // Lógica de registro aqui
                                print('Botão Registrar pressionado!');
                              },
                              style:
                                  ElevatedButton.styleFrom(backgroundColor: Colors.cyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), minimumSize: Size(200.0, 50.0)),
                              child:
                                  Text('Registrar', style: TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold)),
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