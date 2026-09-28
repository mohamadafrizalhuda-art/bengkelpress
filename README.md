# Press Body Motor

Sistem informasi akuntansi pendapatan jasa bengkel berbasis HTML, CSS, JavaScript, Node.js native, dan Supabase Postgres.

## Struktur

- `frontend/` - halaman dashboard, stylesheet, dan JavaScript browser
- `backend/app.js` - server HTTP native dan proxy REST Supabase
- `database/schema.sql` - empat entitas ERD, relasi, policy, index, dan data awal
- `database/enable-master-inserts.sql` - grant dan policy input untuk pelanggan, kendaraan, layanan, dan pendapatan
- `database/operational-features.sql` - tabel booking/antrean tanpa menghapus history

## Menjalankan

1. Jalankan `database/schema.sql` melalui Supabase SQL Editor.
2. Jalankan `database/enable-master-inserts.sql` agar semua form bisa menambah pelanggan, kendaraan, layanan, dan transaksi. Aman dijalankan ulang dan tidak menghapus history.
3. Untuk kalender booking, antrean, status pengerjaan, dan kasir dari tiket selesai, jalankan `database/operational-features.sql`. Migrasi ini aman untuk data yang sudah ada.
4. Buka `backend/app.js`, isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`.
5. Pastikan Node.js 18 atau lebih baru tersedia.
6. Jalankan dari folder utama:

   `node backend/app.js`

7. Buka `http://localhost:3000`.

Ringkasan menampilkan kalender kapasitas dan counter antrean; Layanan menyediakan penerimaan booking/walk-in dengan tiket, status pengerjaan, estimasi, panggilan lokal dan WhatsApp. Pendapatan menyediakan kasir tiket selesai, cetak nota (thermal atau simpan sebagai PDF lewat dialog browser), serta laporan CSV yang kompatibel dengan Excel.

Tidak diperlukan `package.json` atau file `.env.example`. Untuk produksi, simpan publishable key di secret manager dan tambahkan autentikasi pengguna.
