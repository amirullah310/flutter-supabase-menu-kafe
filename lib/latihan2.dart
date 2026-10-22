// Latihan 2 — Menambah Data dengan INSERT
// Jalankan: flutter run -t lib/latihan2.dart
//
// Kelanjutan Latihan 1. Yang ditambahkan:
//   1. Method tambahMenu() → supabase.from('menu').insert({...}).
//   2. Halaman FormTambahMenu dengan validasi (termasuk tugas 5:
//      deskripsi maksimal 100 karakter).
//   3. Tombol "+" yang menunggu hasil formulir (Navigator.push<bool>),
//      lalu memuat ulang daftar bila data berhasil disimpan.
//
// Alur singkat:
//   tombol + → FormTambahMenu → validate() → tambahMenu() → INSERT
//   → Navigator.pop(true) → muatUlang() → SELECT ulang.

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

Future<void> tambahMenu({
  required String nama,
  required String kategori,
  required int harga,
  required String deskripsi,
}) async {
  await supabase.from('menu').insert({
    'nama': nama,
    'kategori': kategori,
    'harga': harga,
    'deskripsi': deskripsi,
    // 'id' tidak diisi — database membuatnya otomatis.
    // 'tersedia' dan 'dibuat_pada' memakai nilai default dari tabel.
  });
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Menunggu hasil dari halaman formulir: true = data berhasil disimpan.
          final berhasil = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const FormTambahMenu()),
          );

          if (berhasil == true) {
            muatUlang();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Menu berhasil ditambahkan')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Menu'),
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
              // Padding bawah 88 agar kartu terakhir tidak tertutup tombol +.
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
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

// ---------------- FORMULIR TAMBAH ----------------
class FormTambahMenu extends StatefulWidget {
  const FormTambahMenu({super.key});

  @override
  State<FormTambahMenu> createState() => _FormTambahMenuState();
}

class _FormTambahMenuState extends State<FormTambahMenu> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _harga = TextEditingController();
  final _deskripsi = TextEditingController();

  String _kategori = 'Makanan';
  bool _sedangMenyimpan = false;

  @override
  void dispose() {
    _nama.dispose();
    _harga.dispose();
    _deskripsi.dispose();
    super.dispose(); // WAJIB: controller harus dibuang agar tidak bocor memori
  }

  Future<void> _simpan() async {
    // Bila ada isian yang tidak valid, berhenti di sini:
    // permintaan ke database TIDAK dikirim sama sekali.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMenyimpan = true);

    try {
      await tambahMenu(
        nama: _nama.text.trim(),
        kategori: _kategori,
        harga: int.parse(_harga.text.trim()),
        deskripsi: _deskripsi.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true); // true = berhasil, dipakai halaman katalog
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _sedangMenyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sedangMenyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Menu'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nama,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nama menu',
                border: OutlineInputBorder(),
              ),
              validator: (nilai) {
                if (nilai == null || nilai.trim().isEmpty) {
                  return 'Nama menu wajib diisi';
                }
                if (nilai.trim().length < 3) {
                  return 'Nama menu minimal 3 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _kategori,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Makanan', child: Text('Makanan')),
                DropdownMenuItem(value: 'Minuman', child: Text('Minuman')),
                DropdownMenuItem(value: 'Camilan', child: Text('Camilan')),
              ],
              onChanged: (nilai) {
                if (nilai == null) return;
                setState(() => _kategori = nilai);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _harga,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga (angka saja)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              validator: (nilai) {
                if (nilai == null || nilai.trim().isEmpty) {
                  return 'Harga wajib diisi';
                }
                final angka = int.tryParse(nilai.trim());
                if (angka == null) return 'Harga harus berupa angka';
                if (angka <= 0) return 'Harga harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deskripsi,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                helperText: 'Maksimal 100 karakter',
                border: OutlineInputBorder(),
              ),
              // Tugas 5: deskripsi boleh kosong, tetapi maksimal 100 karakter.
              validator: (nilai) {
                if (nilai != null && nilai.trim().length > 100) {
                  return 'Deskripsi maksimal 100 karakter '
                      '(sekarang ${nilai.trim().length})';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sedangMenyimpan ? null : _simpan,
              icon: _sedangMenyimpan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_sedangMenyimpan ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
