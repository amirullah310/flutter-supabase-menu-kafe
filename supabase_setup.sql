-- =====================================================================
-- PRAKTIKUM PERTEMUAN 5 — TABEL MENU
-- Jalankan seluruh skrip ini di SQL Editor Supabase (aman dijalankan ulang,
-- kecuali bagian 2 yang akan menambah 5 baris contoh lagi).
-- =====================================================================

-- 1. Tabel utama
create table if not exists public.menu (
  id          bigint primary key generated always as identity,
  nama        text not null,
  kategori    text not null default 'Makanan',
  harga       integer not null default 0,
  deskripsi   text,
  tersedia    boolean not null default true,
  dibuat_pada timestamptz not null default now()
);

-- 2. Data contoh (agar Latihan 1 langsung ada isinya)
insert into public.menu (nama, kategori, harga, deskripsi) values
  ('Mie Aceh',           'Makanan', 25000, 'Mie tebal dengan kuah bumbu rempah khas Aceh'),
  ('Kopi Sanger',        'Minuman', 15000, 'Kopi robusta diseduh dengan susu kental manis'),
  ('Ayam Tangkap',       'Makanan', 35000, 'Ayam goreng dengan daun kari dan daun pandan'),
  ('Pisang Goreng Keju', 'Camilan', 12000, 'Pisang goreng renyah dengan topping keju parut'),
  ('Es Timun Serut',     'Minuman', 10000, 'Minuman segar dari timun serut dan jeruk nipis');

-- 3. Aktifkan Row Level Security (WAJIB)
alter table public.menu enable row level security;

-- 4. Policy untuk praktikum (aplikasi belum memiliki sistem login)
drop policy if exists "menu_baca_publik"   on public.menu;
drop policy if exists "menu_tambah_publik" on public.menu;
drop policy if exists "menu_ubah_publik"   on public.menu;
drop policy if exists "menu_hapus_publik"  on public.menu;

create policy "menu_baca_publik"
  on public.menu for select to anon, authenticated using (true);

create policy "menu_tambah_publik"
  on public.menu for insert to anon, authenticated with check (true);

create policy "menu_ubah_publik"
  on public.menu for update to anon, authenticated using (true) with check (true);

create policy "menu_hapus_publik"
  on public.menu for delete to anon, authenticated using (true);

-- 5. Hak akses Data API
grant select, insert, update, delete on public.menu to anon;
grant select, insert, update, delete on public.menu to authenticated;

-- 6. Izin sequence
grant usage, select on all sequences in schema public to anon;
grant usage, select on all sequences in schema public to authenticated;

-- 7. Latihan 3 tugas 5 — kolom stok (dipakai latihan3.dart dan latihan4.dart)
alter table public.menu add column if not exists stok integer not null default 0;

-- 8. Latihan 4 — aktifkan Realtime untuk tabel menu
--    (sama dengan menyalakan tombol Realtime di Table Editor).
--    Bila muncul pesan "already member of publication", berarti sudah aktif.
alter publication supabase_realtime add table public.menu;
