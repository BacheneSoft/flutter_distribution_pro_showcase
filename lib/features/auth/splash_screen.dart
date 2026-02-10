import 'package:flutter/material.dart';
import 'package:bsoft_app_dist/data/database_helper.dart';
import 'package:bsoft_app_dist/features/clients/client_details_screen.dart';


List<String> communes = []; // Define the communes variable

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/images/Blogo.webp', width: 200, height: 200),
      ),
    );
  }
}



// home screen
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true; // Loading state
  //List<Map<String, dynamic>> _items = []; // List for items data
  final DatabaseHelper dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Fetch clients and users data from local database
  Future<void> _fetchData() async {
    List<Map<String, dynamic>> clients = await dbHelper.getClients();
    //List<Map<String, dynamic>> users =
    await dbHelper.getUsers();
    setState(() {
      _clients = clients;
      //_items = items;
      _isLoading = false;
      _isLoading = false;
    });
  }

  /*// Refresh the clients list when returning from adding/editing client
  Future<void> _navigateToClientForm(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ClientForm(
                communes: [],
              )),
    );
    _fetchData(); // Refresh the list after returning
  }*/

  // Navigate to client details screen
  Future<void> _navigateToClientDetails(
      BuildContext context, Map<String, dynamic> client) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ClientDetailsScreen(client: client)),
    );
    _fetchData(); // Refresh after navigating back from details screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Magasin'),
      ),
      body: SizedBox.expand(
        child: Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  : _clients.isNotEmpty
                      ? Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchData,
                            child: ListView.builder(
                              itemCount: _clients.length,
                              itemBuilder: (BuildContext context, int index) {
                                return ListTile(
                                  title: Text(
                                      _clients[index]['nom'] ?? 'No Name',
                                      style:
                                          TextStyle(color: Color(0xFF141E46))),
                                  subtitle: Text(
                                      _clients[index]['tel'] ?? 'No Phone',
                                      style: TextStyle(
                                          color:
                                              Color.fromARGB(181, 20, 30, 70))),
                                  onTap: () {
                                    _navigateToClientDetails(
                                        context, _clients[index]);
                                  },
                                );
                              },
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text('Pas de Client',
                              style: TextStyle(
                                  fontSize: 18, color: Color(0xFF141E46))),
                        ),
              SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => (), //_navigateToClientForm(context),
                      icon: Icon(Icons.person_add_alt_1,
                          color: Color(0xFF141E46)),
                      label: Text('Ajouter',
                          style: TextStyle(
                              fontSize: 18, color: Color(0xFF141E46))),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        backgroundColor: const Color(0xFFCCFFE5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
