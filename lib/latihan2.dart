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

// Paket bawaan Flutter: semua widget Material (Scaffold, Form, TextFormField, dll).
import 'package:flutter/material.dart';
// Paket Supabase untuk Flutter: Supabase.initialize(), klien database,
// dan PostgrestException (error yang dikirim server database).
import 'package:supabase_flutter/supabase_flutter.dart';

// Berisi supabaseUrl dan supabaseKey (publishable key) milik project kita.
// File ini tidak ikut di-commit ke GitHub (lihat .gitignore).
import 'config.dart';

// =====================================================================
// TITIK MASUK APLIKASI (sama seperti Latihan 1)
// =====================================================================
// main() dibuat `async` karena harus menunggu (await) Supabase siap
// sebelum aplikasi ditampilkan.
Future<void> main() async {
  // Wajib dipanggil bila ada `await` sebelum runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Menyambungkan aplikasi ke project Supabase dengan URL dan
  // publishable key (kunci untuk aplikasi client, dibatasi oleh RLS).
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(const MyApp());
}

/// Klien Supabase — dipakai di seluruh aplikasi, baik untuk membaca
/// (select) maupun menulis (insert) ke database.
final supabase = Supabase.instance.client;

// =====================================================================
// MODEL (sama seperti Latihan 1)
// =====================================================================
// MenuItem mewakili SATU baris dari tabel `menu`.
class MenuItem {
  final int id; // kolom id        (bigint, dibuat otomatis oleh database)
  final String nama; // kolom nama      (text)
  final String kategori; // kolom kategori  (text: Makanan/Minuman/Camilan)
  final int harga; // kolom harga     (integer, dalam rupiah)
  final String deskripsi; // kolom deskripsi (text, boleh kosong)
  final bool tersedia; // kolom tersedia  (boolean)

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

  // Mengubah satu baris dari database (Map) menjadi objek MenuItem.
  // Pola `as Tipe? ?? nilaiDefault` mencegah error bila kolom bernilai null.
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

// =====================================================================
// FUNGSI PEMBANTU (FORMAT TAMPILAN)
// =====================================================================

/// Mengubah angka menjadi format rupiah: 25000 → "Rp 25.000".
String formatRupiah(int nilai) {
  final pola = RegExp(r'\B(?=(\d{3})+(?!\d))');
  final hasil = nilai.toString().replaceAllMapped(pola, (match) => '.');
  return 'Rp $hasil';
}

/// Format sederhana dd/MM/yyyy HH:mm tanpa package tambahan.
/// Contoh: 22/10/2026 13:06. Bila waktunya null, ditampilkan "-".
String formatTanggal(DateTime? waktu) {
  if (waktu == null) return '-';
  // dua(5) → "05": menambahkan nol di depan agar selalu 2 digit.
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${dua(waktu.day)}/${dua(waktu.month)}/${waktu.year} '
      '${dua(waktu.hour)}:${dua(waktu.minute)}';
}

// =====================================================================
// AKSES DATABASE
// =====================================================================

/// READ — mengambil seluruh isi tabel `menu` (sama seperti Latihan 1).
/// Setara SQL: SELECT * FROM menu ORDER BY nama ASC;
Future<List<MenuItem>> ambilDaftarMenu() async {
  final data = await supabase
      .from('menu')
      .select() // SELECT * FROM menu
      // Tugas 5: ganti menjadi ascending: false → urutan Z ke A.
      .order('nama', ascending: true); // ORDER BY nama ASC

  return data.map((baris) => MenuItem.fromJson(baris)).toList();
}

/// CREATE — BARU di Latihan 2: menambah satu baris ke tabel `menu`.
/// Setara SQL: INSERT INTO menu (nama, kategori, harga, deskripsi)
///             VALUES (...);
/// Bila server menolak (mis. policy insert belum ada), fungsi ini melempar
/// PostgrestException; bila internet putus, melempar ClientException.
/// Kedua error itu ditangkap di _simpan() pada halaman formulir.
Future<void> tambahMenu({
  required String nama,
  required String kategori,
  required int harga,
  required String deskripsi,
}) async {
  await supabase.from('menu').insert({
    // Kunci Map = nama kolom di tabel, nilai = isi yang disimpan.
    'nama': nama,
    'kategori': kategori,
    'harga': harga,
    'deskripsi': deskripsi,
    // 'id' tidak diisi — database membuatnya otomatis.
    // 'tersedia' dan 'dibuat_pada' memakai nilai default dari tabel.
  });
}

// =====================================================================
// TAMPILAN: HALAMAN DAFTAR MENU
// =====================================================================

/// Widget paling luar aplikasi: MaterialApp dengan HalamanKatalog
/// sebagai halaman pertama.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false, // menyembunyikan pita "DEBUG"
      home: HalamanKatalog(),
    );
  }
}

/// Halaman daftar menu. StatefulWidget karena isinya dimuat ulang
/// setelah refresh atau setelah menu baru ditambahkan.
class HalamanKatalog extends StatefulWidget {
  const HalamanKatalog({super.key});

  @override
  State<HalamanKatalog> createState() => _HalamanKatalogState();
}

class _HalamanKatalogState extends State<HalamanKatalog> {
  // Future berisi daftar menu dari server; diisi pertama kali di initState().
  late Future<List<MenuItem>> futureMenu;

  // Dipanggil SEKALI saat halaman dibuat. Future tidak dibuat di build()
  // karena build() bisa dipanggil berkali-kali (permintaan jadi berulang).
  @override
  void initState() {
    super.initState();
    futureMenu = ambilDaftarMenu();
  }

  // Mengambil ulang data: dipanggil oleh tombol refresh, tarik-ke-bawah,
  // dan setelah menu baru berhasil disimpan.
  void muatUlang() {
    setState(() {
      futureMenu = ambilDaftarMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ---------- Bilah atas (judul + tombol refresh) ----------
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

      // ---------- Tombol "Tambah Menu" (BARU di Latihan 2) ----------
      // Membuka halaman formulir, lalu MENUNGGU hasilnya.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Menunggu hasil dari halaman formulir: true = data berhasil disimpan.
          // Navigator.push<bool> mengembalikan nilai yang dikirim lewat
          // Navigator.pop(context, true) di formulir; bernilai null bila
          // pengguna menekan tombol kembali tanpa menyimpan.
          final berhasil = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const FormTambahMenu()),
          );

          if (berhasil == true) {
            muatUlang(); // ambil ulang daftar agar menu baru ikut tampil
            // `context` dipakai lagi setelah `await`, jadi pastikan halaman
            // masih ada di layar sebelum menampilkan SnackBar.
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Menu berhasil ditambahkan')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Menu'),
      ),

      // ---------- Isi halaman (sama seperti Latihan 1) ----------
      // FutureBuilder membangun ulang tampilan setiap status Future berubah.
      body: FutureBuilder<List<MenuItem>>(
        future: futureMenu,
        builder: (context, snapshot) {
          // Keadaan 1 — MENUNGGU: permintaan ke server belum selesai.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Keadaan 2 — GAGAL: tampilkan pesan dan tombol "Coba Lagi".
          if (snapshot.hasError) {
            return _tampilanError('${snapshot.error}', muatUlang);
          }

          // Keadaan 3 — BERHASIL tetapi tabel kosong.
          final daftar = snapshot.data ?? [];
          if (daftar.isEmpty) {
            return const Center(
              child: Text('Tabel masih kosong. Tambahkan data dulu.'),
            );
          }

          // Keadaan 4 — BERHASIL dan ada data: tampilkan daftar kartu.
          return RefreshIndicator(
            onRefresh: () async => muatUlang(), // tarik ke bawah = refresh
            child: ListView.builder(
              // Padding bawah 88 agar kartu terakhir tidak tertutup tombol +.
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: daftar.length,
              itemBuilder: (context, index) {
                final menu = daftar[index]; // satu baris menu

                // Satu kartu untuk satu menu.
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    // Kiri: lingkaran berisi id dari database.
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
                    // Judul: nama menu.
                    title: Text(
                      menu.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Subjudul: kategori + deskripsi, lalu tanggal dibuat.
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${menu.kategori} • ${menu.deskripsi}',
                          maxLines: 2, // deskripsi panjang dipotong "..."
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
                    isThreeLine: true, // memberi ruang untuk subjudul 3 baris
                    // Kanan: harga dalam format rupiah.
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

/// Tampilan saat data gagal dimuat: ikon awan, pesan error, dan tombol
/// "Coba Lagi" yang memanggil [onCobaLagi] (di halaman ini: muatUlang()).
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
          // Pesan error asli, mis. "ClientException: Failed to fetch".
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

// =====================================================================
// TAMPILAN: HALAMAN FORMULIR TAMBAH MENU (BARU di Latihan 2)
// =====================================================================

/// Halaman berisi formulir untuk menambah menu baru.
/// StatefulWidget karena isian dan status "sedang menyimpan" bisa berubah.
class FormTambahMenu extends StatefulWidget {
  const FormTambahMenu({super.key});

  @override
  State<FormTambahMenu> createState() => _FormTambahMenuState();
}

class _FormTambahMenuState extends State<FormTambahMenu> {
  // Kunci untuk mengakses Form, dipakai untuk menjalankan semua validator
  // sekaligus lewat _formKey.currentState!.validate().
  final _formKey = GlobalKey<FormState>();

  // Controller menyimpan teks yang diketik pengguna di setiap kolom.
  // Isinya dibaca saat menyimpan, mis. _nama.text.
  final _nama = TextEditingController();
  final _harga = TextEditingController();
  final _deskripsi = TextEditingController();

  // Kategori yang dipilih di dropdown (nilai awal: Makanan).
  String _kategori = 'Makanan';

  // true selama data sedang dikirim ke server: tombol Simpan dinonaktifkan
  // dan menampilkan "Menyimpan..." agar tidak ditekan dua kali.
  bool _sedangMenyimpan = false;

  // dispose() dipanggil saat halaman ditutup.
  @override
  void dispose() {
    _nama.dispose();
    _harga.dispose();
    _deskripsi.dispose();
    super.dispose(); // WAJIB: controller harus dibuang agar tidak bocor memori
  }

  /// Dipanggil saat tombol Simpan ditekan.
  /// Urutan: validasi → tandai sedang menyimpan → INSERT → tutup halaman.
  Future<void> _simpan() async {
    // Bila ada isian yang tidak valid, berhenti di sini:
    // permintaan ke database TIDAK dikirim sama sekali.
    if (!_formKey.currentState!.validate()) return;

    // Tombol berubah menjadi "Menyimpan..." dan tidak bisa ditekan.
    setState(() => _sedangMenyimpan = true);

    try {
      // Kirim data ke database. trim() membuang spasi di awal/akhir teks;
      // int.parse() aman karena validator sudah memastikan harga berupa angka.
      await tambahMenu(
        nama: _nama.text.trim(),
        kategori: _kategori,
        harga: int.parse(_harga.text.trim()),
        deskripsi: _deskripsi.text.trim(),
      );

      // `mounted` memastikan halaman masih ada setelah menunggu server.
      if (!mounted) return;
      Navigator.pop(context, true); // true = berhasil, dipakai halaman katalog
    } on PostgrestException catch (e) {
      // Server MENOLAK permintaan, mis. policy RLS atau grant belum ada.
      if (!mounted) return;
      setState(() => _sedangMenyimpan = false); // tombol aktif lagi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: ${e.message}')),
      );
    } catch (e) {
      // Error lain, mis. internet putus (ClientException: Failed to fetch).
      // Tanpa blok ini, tombol akan macet di "Menyimpan..." tanpa pesan.
      if (!mounted) return;
      setState(() => _sedangMenyimpan = false); // tombol aktif lagi
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
      // Form mengelompokkan semua TextFormField agar bisa divalidasi bersama.
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- Kolom nama ----------
            TextFormField(
              controller: _nama,
              textInputAction: TextInputAction.next, // Enter → kolom berikutnya
              decoration: const InputDecoration(
                labelText: 'Nama menu',
                border: OutlineInputBorder(),
              ),
              // Validator mengembalikan teks error, atau null bila valid.
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

            // ---------- Pilihan kategori ----------
            // Pada Flutter sebelum 3.33, `initialValue:` ditulis `value:`.
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
              // Simpan pilihan baru ke _kategori.
              onChanged: (nilai) {
                if (nilai == null) return;
                setState(() => _kategori = nilai);
              },
            ),
            const SizedBox(height: 16),

            // ---------- Kolom harga ----------
            TextFormField(
              controller: _harga,
              keyboardType: TextInputType.number, // keyboard angka di HP
              decoration: const InputDecoration(
                labelText: 'Harga (angka saja)',
                prefixText: 'Rp ', // tulisan "Rp" di depan isian
                border: OutlineInputBorder(),
              ),
              // Tugas 3: teks seperti "dua ribu" ditolak di sini, sehingga
              // tidak ada permintaan yang dikirim ke database.
              validator: (nilai) {
                if (nilai == null || nilai.trim().isEmpty) {
                  return 'Harga wajib diisi';
                }
                // tryParse menghasilkan null bila teks bukan angka.
                final angka = int.tryParse(nilai.trim());
                if (angka == null) return 'Harga harus berupa angka';
                if (angka <= 0) return 'Harga harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ---------- Kolom deskripsi ----------
            TextFormField(
              controller: _deskripsi,
              maxLines: 3, // kotak isian setinggi 3 baris
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

            // ---------- Tombol Simpan ----------
            // onPressed: null membuat tombol nonaktif selama menyimpan.
            FilledButton.icon(
              onPressed: _sedangMenyimpan ? null : _simpan,
              // Saat menyimpan: ikon diganti indikator loading kecil.
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
