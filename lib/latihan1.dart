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

// Paket bawaan Flutter: semua widget Material (Scaffold, AppBar, Card, dll).
import 'package:flutter/material.dart';
// Paket Supabase untuk Flutter: menyediakan Supabase.initialize() dan klien
// untuk select/insert/update/delete ke database.
import 'package:supabase_flutter/supabase_flutter.dart';

// Berisi supabaseUrl dan supabaseKey (publishable key) milik project kita.
// File ini tidak ikut di-commit ke GitHub (lihat .gitignore).
import 'config.dart';

// =====================================================================
// TITIK MASUK APLIKASI
// =====================================================================
// main() dibuat `async` karena harus menunggu (await) Supabase siap
// sebelum aplikasi ditampilkan.
Future<void> main() async {
  // Wajib dipanggil bila ada `await` sebelum runApp(), agar Flutter
  // sudah siap berkomunikasi dengan platform (penyimpanan, jaringan, dll).
  WidgetsFlutterBinding.ensureInitialized();

  // Menyambungkan aplikasi ke project Supabase.
  // - url            : alamat project (https://xxxx.supabase.co)
  // - publishableKey : kunci untuk aplikasi client (aman disertakan karena
  //                    hak aksesnya dibatasi oleh RLS di database).
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  // Setelah Supabase siap, barulah tampilan aplikasi dijalankan.
  runApp(const MyApp());
}

/// Klien Supabase — dipakai di seluruh aplikasi.
/// Semua akses database ditulis lewat variabel ini, mis.
/// `supabase.from('menu').select()`.
final supabase = Supabase.instance.client;

// =====================================================================
// MODEL
// =====================================================================
// MenuItem mewakili SATU baris dari tabel `menu`.
// Setiap field di sini sesuai dengan satu kolom di tabel.
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

  // Konstruktor: semua field wajib diisi saat objek dibuat.
  const MenuItem({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.harga,
    required this.deskripsi,
    required this.tersedia,
    required this.dibuatPada,
  });

  // Mengubah satu baris dari database (bentuknya Map, mis.
  // {'id': 1, 'nama': 'Mie Aceh', ...}) menjadi objek MenuItem.
  // Pola `as Tipe? ?? nilaiDefault` dipakai agar aplikasi tidak error
  // bila suatu kolom bernilai null.
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
/// Pola RegExp mencari posisi setiap kelipatan 3 digit dari kanan,
/// lalu menyisipkan titik di posisi tersebut.
String formatRupiah(int nilai) {
  final pola = RegExp(r'\B(?=(\d{3})+(?!\d))');
  final hasil = nilai.toString().replaceAllMapped(pola, (match) => '.');
  return 'Rp $hasil';
}

/// Format sederhana dd/MM/yyyy HH:mm tanpa package tambahan.
/// Contoh: 19/10/2026 17:28. Bila waktunya null, ditampilkan "-".
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

/// Mengambil seluruh isi tabel `menu` dari Supabase.
/// Setara SQL: SELECT * FROM menu ORDER BY nama ASC;
/// Hasil select() sudah berupa List<Map>, jadi tidak perlu jsonDecode
/// seperti pada Pertemuan 4.
Future<List<MenuItem>> ambilDaftarMenu() async {
  final data = await supabase
      .from('menu') // tabel yang dituju
      .select() // SELECT * FROM menu
      // Tugas 5: ganti menjadi ascending: false → urutan Z ke A.
      .order('nama', ascending: true); // ORDER BY nama ASC

  // Setiap baris (Map) diubah menjadi objek MenuItem.
  return data.map((baris) => MenuItem.fromJson(baris)).toList();
}

// =====================================================================
// TAMPILAN
// =====================================================================

/// Widget paling luar aplikasi: menyiapkan MaterialApp dan
/// menjadikan HalamanKatalog sebagai halaman pertama.
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

/// Halaman daftar menu. Dibuat StatefulWidget karena isinya bisa
/// berubah (dimuat ulang saat tombol refresh ditekan).
class HalamanKatalog extends StatefulWidget {
  const HalamanKatalog({super.key});

  @override
  State<HalamanKatalog> createState() => _HalamanKatalogState();
}

class _HalamanKatalogState extends State<HalamanKatalog> {
  // Future berisi daftar menu yang sedang/akan diambil dari server.
  // `late` artinya nilainya baru diisi nanti, yaitu di initState().
  late Future<List<MenuItem>> futureMenu;

  // initState() dipanggil SEKALI saat halaman pertama kali dibuat.
  // Future sengaja dibuat di sini, BUKAN di build(), karena build() bisa
  // dipanggil berkali-kali dan setiap pemanggilan akan mengirim
  // permintaan baru ke server.
  @override
  void initState() {
    super.initState();
    futureMenu = ambilDaftarMenu();
  }

  // Dipanggil saat tombol refresh ditekan atau daftar ditarik ke bawah.
  // setState() memberi Future baru, sehingga FutureBuilder mengambil
  // data terbaru dari database.
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
            onPressed: muatUlang, // ambil ulang data dari database
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),

      // ---------- Isi halaman ----------
      // FutureBuilder membangun ulang tampilan setiap kali status Future
      // berubah: menunggu → selesai (berhasil atau gagal).
      body: FutureBuilder<List<MenuItem>>(
        future: futureMenu,
        builder: (context, snapshot) {
          // Keadaan 1 — MENUNGGU: permintaan ke server belum selesai.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Keadaan 2 — GAGAL: mis. internet putus atau kunci salah.
          // Ditampilkan pesan error dan tombol "Coba Lagi".
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

          // Keadaan 4 — BERHASIL dan ada data: tampilkan daftar.
          // RefreshIndicator memungkinkan "tarik ke bawah untuk refresh".
          return RefreshIndicator(
            onRefresh: () async => muatUlang(),
            // ListView.builder hanya membangun kartu yang terlihat di layar,
            // jadi tetap ringan walaupun datanya banyak.
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
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

/// Tampilan saat data gagal dimuat: ikon awan, pesan error dari
/// server/jaringan, dan tombol "Coba Lagi" yang memanggil [onCobaLagi]
/// (di halaman ini: muatUlang()).
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
