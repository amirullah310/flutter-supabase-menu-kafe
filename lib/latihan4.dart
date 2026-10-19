// Latihan 4 — Proyek Mini: CRUD Realtime dengan Pencarian dan Filter
// Jalankan: flutter run -t lib/latihan4.dart
//
// Kelanjutan Latihan 3. Hanya class _HalamanKatalogState yang diganti:
//   1. FutureBuilder → StreamBuilder dengan .stream(primaryKey: ['id']).
//      Stream dibuat SEKALI di initState, bukan di build().
//   2. Kolom pencarian + ChoiceChip kategori, disaring di sisi aplikasi
//      (tanpa memanggil ulang server).
//   3. Tidak ada lagi muatUlang(): tambah/ubah/hapus dari perangkat mana pun
//      (termasuk Table Editor) masuk sendiri lewat stream.
//   4. Nilai tambah: pengurutan (nama / termurah / termahal) dan
//      keterangan "Menampilkan x dari y menu".
//
// Syarat: Realtime untuk tabel `menu` sudah diaktifkan di dashboard Supabase.

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

/// Pilihan pengurutan (tugas 7, nilai tambah).
enum Urutan {
  nama('Nama (A–Z)'),
  termurah('Harga termurah'),
  termahal('Harga termahal');

  const Urutan(this.label);
  final String label;
}

class _HalamanKatalogState extends State<HalamanKatalog> {
  // Stream disimpan sebagai variabel. JANGAN dibuat di dalam build(),
  // karena build() dapat dipanggil berkali-kali dan koneksi realtime akan terputus.
  late Stream<List<Map<String, dynamic>>> _streamMenu;

  String _kataKunci = '';
  String _kategoriTerpilih = 'Semua';
  Urutan _urutan = Urutan.nama;

  /// id baris yang sudah digeser tetapi belum dikonfirmasi terhapus oleh stream.
  /// Disembunyikan dari daftar agar Dismissible yang sudah digeser tidak
  /// dibangun ulang (mis. saat mengetik di kolom pencarian) sebelum stream
  /// mengirim data terbaru. Bila hapus gagal, id dikeluarkan lagi sehingga
  /// baris muncul kembali.
  final Set<int> _sedangDihapus = {};

  @override
  void initState() {
    super.initState();
    _buatStream();
  }

  void _buatStream() {
    _streamMenu = supabase
        .from('menu')
        .stream(primaryKey: ['id']) // kolom identitas baris — wajib diisi
        .order('nama', ascending: true);
  }

  Future<void> _bukaForm({MenuItem? menu}) async {
    final berhasil = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => FormMenu(menu: menu)),
    );

    if (berhasil == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(menu == null ? 'Menu ditambahkan' : 'Perubahan disimpan'),
          duration: const Duration(seconds: 1),
        ),
      );
      // Tidak perlu memuat ulang: perubahan akan datang sendiri lewat stream.
    }
  }

  Future<void> _balikKetersediaan(MenuItem menu) async {
    try {
      await ubahKetersediaan(id: menu.id, tersedia: !menu.tersedia);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah ketersediaan: $e')),
      );
    }
  }

  List<MenuItem> _urutkan(List<MenuItem> daftar) {
    switch (_urutan) {
      case Urutan.nama:
        break; // sudah diurutkan oleh .order('nama') di stream
      case Urutan.termurah:
        daftar.sort((a, b) => a.harga.compareTo(b.harga));
      case Urutan.termahal:
        daftar.sort((a, b) => b.harga.compareTo(a.harga));
    }
    return daftar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Kafe (Realtime)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<Urutan>(
            icon: const Icon(Icons.sort),
            tooltip: 'Urutkan',
            initialValue: _urutan,
            onSelected: (pilihan) => setState(() => _urutan = pilihan),
            itemBuilder: (context) => [
              for (final u in Urutan.values)
                PopupMenuItem(value: u, child: Text(u.label)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama menu...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (nilai) => setState(() => _kataKunci = nilai),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kategori in const [
                  'Semua',
                  'Makanan',
                  'Minuman',
                  'Camilan',
                ])
                  ChoiceChip(
                    label: Text(kategori),
                    selected: _kategoriTerpilih == kategori,
                    onSelected: (dipilih) {
                      setState(() => _kategoriTerpilih = kategori);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _streamMenu,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _tampilanError(
                    '${snapshot.error}',
                    () => setState(_buatStream),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Semua baris dari database diubah menjadi objek.
                final semua = snapshot.data!
                    .map((baris) => MenuItem.fromJson(baris))
                    .where((menu) => !_sedangDihapus.contains(menu.id))
                    .toList();

                // Penyaringan dilakukan di sisi aplikasi agar daftar tetap
                // realtime. Cara lain: memfilter di sisi database dengan .eq().
                final hasil = _urutkan(semua.where((menu) {
                  final cocokKata = menu.nama
                      .toLowerCase()
                      .contains(_kataKunci.trim().toLowerCase());
                  final cocokKategori = _kategoriTerpilih == 'Semua' ||
                      menu.kategori == _kategoriTerpilih;
                  return cocokKata && cocokKategori;
                }).toList());

                if (hasil.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        semua.isEmpty
                            ? 'Tabel masih kosong. Tekan "Tambah" untuk mengisi.'
                            : 'Tidak ada menu yang cocok dengan pencarian.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Tugas 8 (nilai tambah): jumlah menu yang sedang tampil.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Menampilkan ${hasil.length} dari ${semua.length} menu',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const Spacer(),
                          Text(
                            _urutan.label,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        // Padding bawah 88 agar baris terakhir tidak tertutup tombol.
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                        itemCount: hasil.length,
                        itemBuilder: (context, index) {
                          final menu = hasil[index];
                          return _kartuMenu(menu);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuMenu(MenuItem menu) {
    return Dismissible(
      key: ValueKey(menu.id),
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
                content:
                    Text('"${menu.nama}" akan dihapus permanen dari database.'),
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
      // PERUBAHAN 1 — daftar tidak lagi dimuat ulang secara manual.
      onDismissed: (arah) async {
        setState(() => _sedangDihapus.add(menu.id));
        try {
          await hapusMenu(menu.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${menu.nama}" dihapus')),
          );
        } catch (e) {
          if (!mounted) return;
          // Gagal: tampilkan lagi barisnya.
          setState(() => _sedangDihapus.remove(menu.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e')),
          );
        }
        // Tidak ada futureMenu maupun muatUlang() di sini:
        // stream akan memperbarui daftar dengan sendirinya.
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor:
                menu.tersedia ? Colors.teal.shade50 : Colors.grey.shade200,
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
            style:
                const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          // PERUBAHAN 2 — tap membuka formulir mode edit.
          onTap: () => _bukaForm(menu: menu),
          onLongPress: () => _balikKetersediaan(menu),
        ),
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
