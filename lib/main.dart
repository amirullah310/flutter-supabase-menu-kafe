// Titik masuk: menggabungkan Latihan 1 sampai 4 dalam satu TabBar.
// Masing-masing latihan tetap bisa dijalankan sendiri:
//   flutter run -t lib/latihan1.dart
//   flutter run -t lib/latihan2.dart
//   flutter run -t lib/latihan3.dart
//   flutter run -t lib/latihan4.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
// Prefix dipakai karena setiap latihan punya class HalamanKatalog sendiri.
import 'latihan1.dart' as l1;
import 'latihan2.dart' as l2;
import 'latihan3.dart' as l3;
import 'latihan4.dart' as l4;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // wajib: ada await sebelum runApp

  // Cukup sekali; keempat latihan memakai Supabase.instance.client yang sama.
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(const AplikasiPraktikum());
}

class AplikasiPraktikum extends StatelessWidget {
  const AplikasiPraktikum({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const HalamanTab(),
    );
  }
}

class HalamanTab extends StatelessWidget {
  const HalamanTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        // Setiap latihan sudah punya AppBar sendiri, jadi TabBar diletakkan
        // di bawah agar tidak ada dua AppBar bertumpuk.
        body: const TabBarView(
          // Geser kiri dipakai untuk menghapus menu, jadi geser antar-tab
          // dimatikan agar keduanya tidak berebut gerakan.
          physics: NeverScrollableScrollPhysics(),
          children: [
            _TetapHidup(child: l1.HalamanKatalog()),
            _TetapHidup(child: l2.HalamanKatalog()),
            _TetapHidup(child: l3.HalamanKatalog()),
            _TetapHidup(child: l4.HalamanKatalog()),
          ],
        ),
        bottomNavigationBar: Material(
          color: Colors.teal.shade700,
          child: const SafeArea(
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(icon: Icon(Icons.table_rows), text: 'Latihan 1'),
                Tab(icon: Icon(Icons.add_box), text: 'Latihan 2'),
                Tab(icon: Icon(Icons.edit_note), text: 'Latihan 3'),
                Tab(icon: Icon(Icons.bolt), text: 'Latihan 4'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Menjaga state halaman tetap hidup saat berpindah tab,
/// supaya data tidak diambil ulang dari server setiap kali tab diganti.
class _TetapHidup extends StatefulWidget {
  final Widget child;
  const _TetapHidup({required this.child});

  @override
  State<_TetapHidup> createState() => _TetapHidupState();
}

class _TetapHidupState extends State<_TetapHidup>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
