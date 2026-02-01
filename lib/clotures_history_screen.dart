import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class CloturesHistoryScreen extends StatefulWidget {
  const CloturesHistoryScreen({Key? key}) : super(key: key);

  @override
  _CloturesHistoryScreenState createState() => _CloturesHistoryScreenState();
}

class _CloturesHistoryScreenState extends State<CloturesHistoryScreen> {
  List<Map<String, dynamic>> clotures = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClotures();
  }

  Future<void> _loadClotures() async {
    setState(() => isLoading = true);
    final db = DatabaseHelper();
    final results = await db.getCloturesHistory();
    setState(() {
      clotures = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historique des Clôtures',
          style: TextStyle(
            fontFamily: 'Bahnschrift',
            fontSize: 24,
            color: Color(0xFF19264C),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF19264C)),
      ),
      body: Container(
        color: const Color(0xFFFAFAFF),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : clotures.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune clôture enregistrée',
                      style: TextStyle(
                        fontFamily: 'ZTGatha',
                        fontSize: 18,
                        color: Color(0xFF19264C),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: clotures.length,
                    itemBuilder: (context, index) {
                      final cloture = clotures[index];
                      final date = cloture['cloture_date']?.toString() ?? '';
                      DateTime? parsedDate;
                      try {
                        parsedDate = DateTime.parse(date);
                      } catch (e) {
                        parsedDate = null;
                      }
                      final formattedDate = parsedDate != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(parsedDate)
                          : date;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontFamily: 'Bahnschrift',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF19264C),
                                    ),
                                  ),
                                  Text(
                                    '${((cloture['montant'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DA',
                                    style: const TextStyle(
                                      fontFamily: 'ZTGatha',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    'Encaissement',
                                    (cloture['encaissement'] as num?)?.toDouble() ?? 0.0,
                                    Colors.blue,
                                  ),
                                  _buildStatItem(
                                    'Chiffre d\'affaire',
                                    (cloture['chiffre_affaire'] as num?)?.toDouble() ?? 0.0,
                                    Colors.orange,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'ZTGatha',
            fontSize: 12,
            color: Color(0xFF19264C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(2)} DA',
          style: TextStyle(
            fontFamily: 'ZTGatha',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

