// Latihan 1 — Dari Dashboard ke Aplikasi: SELECT Pertama
// Jalankan: flutter run -t lib/latihan1.dart
//
// Tujuan latihan:
//   1. Menghubungkan aplikasi ke project Supabase (Supabase.initialize).
//   2. Mengambil isi tabel `menu` dengan select() + order().
//   3. Membuktikan bahwa data yang tampil berasal dari database cloud,
//      bukan dari kode program.
//
// Alur singkat:
//   initState() → ambilDaftarMenu() → supabase.from('menu').select()
//   → List<Map> → MenuItem.fromJson() → FutureBuilder menampilkan daftar.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // wajib: ada await sebelum runApp

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(const MyApp());
}

/// Klien Supabase — dipakai di seluruh aplikasi.
final supabase = Supabase.instance.client;

// ---------------- MODEL ----------------
class MenuItem {
  final int id;
  final String nama;
  final String kategori;
  final int harga;
  final String deskripsi;
  final bool tersedia;

  /// Tugas 4: kolom `timestamptz` dibaca sebagai DateTime.
  /// Dibuat nullable agar aman bila kolom tidak ikut terkirim.
  final DateTime? dibuatPada;

  const MenuItem({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.harga,
    required this.deskripsi,
    required this.tersedia,
    required this.dibuatPada,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      // bigint dari Postgres tiba sebagai angka, jadi dikonversi dengan aman.
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '-',
      kategori: json['kategori'] as String? ?? 'Lainnya',
      harga: (json['harga'] as num?)?.toInt() ?? 0,
      deskripsi: json['deskripsi'] as String? ?? '',
      tersedia: json['tersedia'] as bool? ?? true,
      // timestamptz tiba sebagai teks ISO 8601 (zona UTC), mis.
      // "2026-10-19T08:15:00.123+00:00" → diubah ke waktu lokal perangkat.
      dibuatPada:
          DateTime.tryParse(json['dibuat_pada'] as String? ?? '')?.toLocal(),
    );
  }
}

String formatRupiah(int nilai) {
  final pola = RegExp(r'\B(?=(\d{3})+(?!\d))');
  final hasil = nilai.toString().replaceAllMapped(pola, (match) => '.');
  return 'Rp $hasil';
}

/// Format sederhana dd/MM/yyyy HH:mm tanpa package tambahan.
String formatTanggal(DateTime? waktu) {
  if (waktu == null) return '-';
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${dua(waktu.day)}/${dua(waktu.month)}/${waktu.year} '
      '${dua(waktu.hour)}:${dua(waktu.minute)}';
}

// ---------------- AKSES DATABASE ----------------
Future<List<MenuItem>> ambilDaftarMenu() async {
  final data = await supabase
      .from('menu')
      .select() // SELECT * FROM menu
      // Tugas 5: ganti menjadi ascending: false → urutan Z ke A.
      .order('nama', ascending: true); // ORDER BY nama ASC

  return data.map((baris) => MenuItem.fromJson(baris)).toList();
}

// ---------------- TAMPILAN ----------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HalamanKatalog(),
    );
  }
}

class HalamanKatalog extends StatefulWidget {
  const HalamanKatalog({super.key});

  @override
  State<HalamanKatalog> createState() => _HalamanKatalogState();
}

class _HalamanKatalogState extends State<HalamanKatalog> {
  late Future<List<MenuItem>> futureMenu;

  @override
  void initState() {
    super.initState();
    futureMenu = ambilDaftarMenu();
  }

  void muatUlang() {
    setState(() {
      futureMenu = ambilDaftarMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Kafe (Supabase)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: muatUlang,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: FutureBuilder<List<MenuItem>>(
        future: futureMenu,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _tampilanError('${snapshot.error}', muatUlang);
          }

          final daftar = snapshot.data ?? [];
          if (daftar.isEmpty) {
            return const Center(
              child: Text('Tabel masih kosong. Tambahkan data dulu.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => muatUlang(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: daftar.length,
              itemBuilder: (context, index) {
                final menu = daftar[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: Text(
                        '${menu.id}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      menu.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${menu.kategori} • ${menu.deskripsi}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Tugas 4: kolom dibuat_pada ditampilkan di baris sendiri.
                        Text(
                          'Dibuat: ${formatTanggal(menu.dibuatPada)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      formatRupiah(menu.harga),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

Widget _tampilanError(String pesan, VoidCallback onCobaLagi) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(pesan,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onCobaLagi,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    ),
  );
}
