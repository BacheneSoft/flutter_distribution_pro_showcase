import 'login.dart';
import 'sold_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'splashcreen.dart';

// Log out function
void _logout(BuildContext context) async {
  // Get SharedPreferences instance
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Clear login status and userId from SharedPreferences
  await prefs.remove('loggedIn');
  await prefs
      .remove('userId'); // Optionally clear other user-specific data if stored

  // Optionally, you can use prefs.clear() to clear all keys (if you want to clear everything)

  // Navigate the user to the login screen after logging out
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => LoginScreen()),
  );
}

class HomeButtons extends StatefulWidget {
  @override
  _HomeButtonsState createState() => _HomeButtonsState();
}

class _HomeButtonsState extends State<HomeButtons> {
  bool isLoggedIn = false; // Add this to track login state
  String? userId;
  @override
  void initState() {
    super.initState();
    checkLoginStatus(); // Ensure we load the cached user and routes
  }

  // Check if the user is logged in
  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('loggedIn') ?? false;
    userId = prefs.getString('userId'); // Retrieve the stored userId
    print("Login status in checkLoginStatus: $isLoggedIn, User ID: $userId");

    if (isLoggedIn && userId != null) {
      print('User is logged in with ID: $userId');
      fetchRoutesForUser(); // Fetch routes after confirming login
    } else {
      print('No user is logged in $userId and $isLoggedIn');
      _navigateToLogin();
    }
  }

  // Function to fetch routes for the connected user from Local DB
  Future<void> fetchRoutesForUser() async {
    if (userId == null) {
      print("userId is null, not fetching routes");
      return;
    }

    print("Fetching routes for userId: $userId");

    try {
      // Assuming userId is the 'nom' (username) as per original logic
      final db = DatabaseHelper();
      final users = await db.getUsers();

      final user = users.firstWhere(
        (u) => u['nom'] == userId,
        orElse: () => {},
      );

      if (user.isNotEmpty) {
        String routesString = user['route'] ?? '';
        // Assuming routes are stored as comma separated string or similar in local DB
        // Original code had jsonEncode(['Route 1', ...]) but let's handle simple string split for now
        // based on my DatabaseHelper update: 'Route 1, Route 2'

        List<String> routes =
            routesString.split(',').map((e) => e.trim()).toList();

        print("Routes fetched: $routes");

        setState(() {
          communes = routes;
        });
      } else {
        print("No matching user found for userId: $userId");
        setState(() {
          communes = [];
        });
      }
    } catch (e) {
      print("Error fetching routes: $e");
    }
  }

  /*void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => HomeButtons()), // Navigate to home
    );
  }*/

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => LoginScreen()), // Navigate to login
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFAFAFF),
            Color(0xFF4A69BD),
          ],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text("Bienvenue "),
          backgroundColor: Colors.transparent,
        ),
        drawer: _buildDrawer(context),
        backgroundColor: Colors.transparent,
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // 2 columns
                children: <Widget>[
                  _buildSquareIconButton(
                      context, 'assets/images/store.png', 'Magasin', true),
                  _buildSquareIconButton(
                      context, 'assets/images/selling.png', 'Vente', true),
                  _buildSquareIconButton(
                      context, 'assets/images/stock.png', 'Stock', false),
                  _buildSquareIconButton(
                      context, 'assets/images/order.png', 'Commande', false),
                  _buildSquareIconButton(
                      context, 'assets/images/dataentry.png', 'Saisie', false),
                  _buildSquareIconButton(
                      context, 'assets/images/payment.png', 'Paiement', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.grey[200], // Change the background color here
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(
                    0xFF141E46), // You can keep the header color different if needed
              ),
              child: Text(
                'Profile',
                style: TextStyle(
                  color: Colors.grey[200],
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('Log out'),
              onTap: () {
                _logout(context); // Log out functionality
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareIconButton(
      BuildContext context, String iconPath, String label, bool isNavigable) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromARGB(0, 207, 206, 206),
          foregroundColor: Color.fromARGB(255, 7, 8, 15),
          padding: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8), // Square shape with rounded corners
          ),
        ),
        onPressed: isNavigable
            ? () {
                if (label == "Magasin") {
                  // Navigate to HomeScreen when Magasin button is clicked
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                  );
                } else if (label == "Vente") {
                  // Navigate to SoldScreen when Vente button is clicked
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SoldScreen()),
                  );
                }
              }
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              iconPath,
              height: 100, // Custom icon size
              width: 100, // Adjust as per your preference
            ),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(fontSize: 22), // Slightly smaller text size
            ),
          ],
        ),
      ),
    );
  }
}
