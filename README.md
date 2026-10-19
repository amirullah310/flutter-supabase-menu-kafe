# flutter-supabase-menu-kafe

Aplikasi menu kafe berbasis Flutter + Supabase dengan CRUD lengkap dan pembaruan realtime.
Dikerjakan untuk Praktikum Pemrograman Mobile Pertemuan 5, Teknik Informatika, Politeknik Negeri Lhokseumawe.

## Isi

| File | Latihan |
|---|---|
| `lib/latihan1.dart` | SELECT pertama: daftar menu dari database |
| `lib/latihan2.dart` | INSERT: formulir tambah menu dengan validasi |
| `lib/latihan3.dart` | UPDATE & DELETE: ubah lewat tap, hapus lewat geser + konfirmasi, kolom `stok` |
| `lib/latihan4.dart` | Realtime (`.stream()` + `StreamBuilder`), pencarian, filter kategori, pengurutan |
| `lib/main.dart` | Menggabungkan keempat latihan dalam tab |
| `supabase_setup.sql` | Tabel `menu`, data contoh, RLS + policy, grant, Realtime |

## Menjalankan

1. Buat project di [supabase.com](https://supabase.com), lalu jalankan seluruh isi `supabase_setup.sql` di **SQL Editor**.
2. Salin `lib/config.example.dart` menjadi `lib/config.dart`, lalu isi **Project URL** dan **Publishable key** (`sb_publishable_...`). Jangan memakai secret key.
3. Jalankan:

   ```bash
   flutter pub get
   flutter run                      # keempat latihan dalam tab
   flutter run -t lib/latihan4.dart # satu latihan saja
   ```

`lib/config.dart` sengaja tidak di-commit (lihat `.gitignore`).

> Policy pada `supabase_setup.sql` memakai `using (true)` karena aplikasi belum memiliki login. Ini hanya untuk latihan, bukan untuk aplikasi produksi.
