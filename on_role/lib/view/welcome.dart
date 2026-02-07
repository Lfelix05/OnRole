import 'package:flutter/material.dart';
import 'register_view.dart';
import 'login_view.dart';
  
class WelcomeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Fundo com imagem/gradiente que simula um mapa GPS noturno
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.location_on, // icone de localização
                    color: Colors.cyanAccent,
                    size: 100.0,
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    'OnRolê',
                    style: TextStyle(
                      fontSize: 48.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(height: 180.0),
                  Text(
                    'Onde a noite te chama.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.0,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 30.0),
                  // (Login)
                  SizedBox(
                    width: double.infinity,
                    height: 50.0,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => LoginView()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan, // Cor principal do botão
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        'ENTRAR',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.0),
                  // (Registrar-se)
                  SizedBox(
                    width: double.infinity,
                    height: 50.0,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterView()));
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white, // Cor do texto do botão
                        side: BorderSide(color: Colors.deepPurpleAccent, width: 2.0), // Borda roxa
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        'REGISTRAR-SE',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}