// Latihan 3 — Mengubah dan Menghapus (UPDATE & DELETE)
// Jalankan: flutter run -t lib/latihan3.dart
//
// Kelanjutan Latihan 2. Yang ditambahkan/diubah:
//   1. Tiga method baru: ubahMenu(), ubahKetersediaan(), hapusMenu().
//      Ketiganya SELALU memakai filter .eq('id', id).
//   2. FormTambahMenu menjadi FormMenu dengan dua mode (tambah / edit).
//   3. itemBuilder diganti: geser ke kiri = hapus (dengan dialog konfirmasi),
//      tap = buka formulir mode edit, tekan lama = ubah ketersediaan.
//   4. Tugas 5: kolom baru `stok` (integer). Jalankan dulu di SQL Editor:
//        alter table public.menu add column if not exists stok integer not null default 0;
//
// Alur hapus:
//   geser → confirmDismiss (dialog) → onDismissed → _hapusLaluMuatUlang()
//   → DELETE ... WHERE id = ? → SELECT ulang → FutureBuilder.

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
  final DateTime? dibuatPada;

  /// Tugas 5: kolom baru `stok integer not null default 0`.
  final int stok;

  const MenuItem({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.harga,
    required this.deskripsi,
    required this.tersedia,
    required this.dibuatPada,
    required this.stok,
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
      dibuatPada:
          DateTime.tryParse(json['dibuat_pada'] as String? ?? '')?.toLocal(),
      stok: (json['stok'] as num?)?.toInt() ?? 0,
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
      .order('nama', ascending: true); // ORDER BY nama ASC

  return data.map((baris) => MenuItem.fromJson(baris)).toList();
}

Future<void> tambahMenu({
  required String nama,
  required String kategori,
  required int harga,
  required String deskripsi,
  required int stok,
}) async {
  await supabase.from('menu').insert({
    'nama': nama,
    'kategori': kategori,
    'harga': harga,
    'deskripsi': deskripsi,
    'stok': stok,
    // 'id' tidak diisi — database membuatnya otomatis.
    // 'tersedia' dan 'dibuat_pada' memakai nilai default dari tabel.
  });
}

Future<void> ubahMenu({
  required int id,
  required String nama,
  required String kategori,
  required int harga,
  required String deskripsi,
  required bool tersedia,
  required int stok,
}) async {
  await supabase.from('menu').update({
    'nama': nama,
    'kategori': kategori,
    'harga': harga,
    'deskripsi': deskripsi,
    'tersedia': tersedia,
    'stok': stok,
  }).eq('id', id); // TANPA .eq() → SELURUH tabel akan terubah!
}

Future<void> ubahKetersediaan({required int id, required bool tersedia}) async {
  await supabase.from('menu').update({'tersedia': tersedia}).eq('id', id);
}

Future<void> hapusMenu(int id) async {
  // Tugas 4 (percobaan berbahaya): bila .eq('id', id) dihapus, SELURUH baris
  // tabel ikut terhapus. Sudah dikembalikan seperti semula.
  await supabase.from('menu').delete().eq('id', id);
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

  /// Hapus di database DULU, baru ambil ulang daftar (lihat tugas 6).
  Future<List<MenuItem>> _hapusLaluMuatUlang(int id) async {
    await hapusMenu(id);
    return ambilDaftarMenu();
  }

  /// Tekan lama pada kartu: membalik status tersedia tanpa membuka formulir.
  Future<void> _balikKetersediaan(MenuItem menu) async {
    try {
      await ubahKetersediaan(id: menu.id, tersedia: !menu.tersedia);
      if (!mounted) return;
      muatUlang();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${menu.nama}" ditandai '
            '${menu.tersedia ? 'TIDAK tersedia' : 'tersedia'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah ketersediaan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Kafe (CRUD)'),
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
            MaterialPageRoute(builder: (context) => const FormMenu()),
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

                return Dismissible(
                  key: ValueKey(menu.id), // wajib unik untuk setiap baris
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (arah) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Hapus menu?'),
                            content: Text(
                                '"${menu.nama}" akan dihapus permanen dari database.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Batal'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (arah) {
                    // Hapus di database DULU, baru muat ulang daftar.
                    // Urutan ini penting: bila daftar dimuat ulang sebelum
                    // penghapusan selesai, baris yang sudah digeser akan muncul
                    // kembali dan Flutter melempar error
                    // "A dismissed Dismissible widget is still part of the tree".
                    setState(() {
                      futureMenu = _hapusLaluMuatUlang(menu.id);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${menu.nama}" dihapus')),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: menu.tersedia
                            ? Colors.teal.shade50
                            : Colors.grey.shade200,
                        child: Text(
                          '${menu.id}',
                          style: TextStyle(
                            color: menu.tersedia ? Colors.teal : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        menu.nama,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          // Menu yang tidak tersedia ditampilkan lebih redup.
                          color: menu.tersedia ? null : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        '${menu.kategori} • Stok ${menu.stok}'
                        '${menu.tersedia ? '' : ' • TIDAK TERSEDIA'}\n'
                        '${menu.deskripsi}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        formatRupiah(menu.harga),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      onTap: () async {
                        final berhasil = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (context) => FormMenu(menu: menu)),
                        );
                        if (berhasil == true && context.mounted) {
                          muatUlang();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Perubahan disimpan')),
                          );
                        }
                      },
                      onLongPress: () => _balikKetersediaan(menu),
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

// ---------------- FORMULIR TAMBAH / UBAH ----------------
class FormMenu extends StatefulWidget {
  const FormMenu({super.key, this.menu});

  /// null  → mode TAMBAH
  /// terisi → mode EDIT
  final MenuItem? menu;

  @override
  State<FormMenu> createState() => _FormMenuState();
}

class _FormMenuState extends State<FormMenu> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nama;
  late final TextEditingController _harga;
  late final TextEditingController _stok;
  late final TextEditingController _deskripsi;

  late String _kategori;
  late bool _tersedia;
  bool _sedangMenyimpan = false;

  bool get _modeEdit => widget.menu != null;

  @override
  void initState() {
    super.initState();

    // Isi awal: dari data yang ada (mode edit) atau kosong (mode tambah).
    final menu = widget.menu;
    _nama = TextEditingController(text: menu?.nama ?? '');
    _harga = TextEditingController(text: menu == null ? '' : '${menu.harga}');
    _stok = TextEditingController(text: menu == null ? '0' : '${menu.stok}');
    _deskripsi = TextEditingController(text: menu?.deskripsi ?? '');
    _kategori = menu?.kategori ?? 'Makanan';
    _tersedia = menu?.tersedia ?? true;
  }

  @override
  void dispose() {
    _nama.dispose();
    _harga.dispose();
    _stok.dispose();
    _deskripsi.dispose();
    super.dispose();
  }

  /// Daftar pilihan kategori. Nilai dari database selalu dimasukkan,
  /// agar dropdown tidak error bila data memakai kategori di luar daftar bawaan.
  List<String> get _pilihanKategori {
    const bawaan = ['Makanan', 'Minuman', 'Camilan'];
    if (bawaan.contains(_kategori)) return bawaan;
    return [_kategori, ...bawaan];
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMenyimpan = true);

    try {
      if (_modeEdit) {
        await ubahMenu(
          id: widget.menu!.id,
          nama: _nama.text.trim(),
          kategori: _kategori,
          harga: int.parse(_harga.text.trim()),
          deskripsi: _deskripsi.text.trim(),
          tersedia: _tersedia,
          stok: int.parse(_stok.text.trim()),
        );
      } else {
        await tambahMenu(
          nama: _nama.text.trim(),
          kategori: _kategori,
          harga: int.parse(_harga.text.trim()),
          deskripsi: _deskripsi.text.trim(),
          stok: int.parse(_stok.text.trim()),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
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
        title: Text(_modeEdit ? 'Ubah Menu' : 'Tambah Menu'),
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
              items: _pilihanKategori
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (nilai) {
                if (nilai == null) return;
                setState(() => _kategori = nilai);
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _stok,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok',
                      border: OutlineInputBorder(),
                    ),
                    validator: (nilai) {
                      final angka = int.tryParse(nilai?.trim() ?? '');
                      if (angka == null) return 'Stok harus angka';
                      if (angka < 0) return 'Tidak boleh negatif';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deskripsi,
              maxLines: 3,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              value: _tersedia,
              onChanged: (nilai) => setState(() => _tersedia = nilai),
              title: const Text('Tersedia'),
              subtitle:
                  const Text('Menu yang tidak tersedia ditandai pada daftar'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
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
