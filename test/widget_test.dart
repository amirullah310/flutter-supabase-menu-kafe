import 'package:flutter_test/flutter_test.dart';

import 'package:pnl_supabase/latihan1.dart';

void main() {
  test('MenuItem.fromJson membaca baris dari Supabase', () {
    final menu = MenuItem.fromJson({
      'id': 1,
      'nama': 'Mie Aceh',
      'kategori': 'Makanan',
      'harga': 25000,
      'deskripsi': null,
      'tersedia': true,
      'dibuat_pada': '2026-10-19T08:15:00+00:00',
    });

    expect(menu.id, 1);
    expect(menu.deskripsi, '');
    expect(menu.dibuatPada, DateTime.utc(2026, 10, 19, 8, 15).toLocal());
  });

  test('formatRupiah memakai titik pemisah ribuan', () {
    expect(formatRupiah(25000), 'Rp 25.000');
    expect(formatRupiah(1250000), 'Rp 1.250.000');
  });
}
