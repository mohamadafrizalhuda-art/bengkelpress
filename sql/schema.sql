-- Sistem Informasi Akuntansi Pendapatan Jasa Bengkel Press Body Motor
-- Jalankan seluruh script ini di Supabase SQL Editor.

create extension if not exists "pgcrypto";

drop view if exists laporan_pendapatan cascade;
drop function if exists set_updated_at() cascade;
drop function if exists buat_nomor_transaksi() cascade;
drop table if exists pendapatan cascade;
drop table if exists kendaraan cascade;
drop table if exists layanan cascade;
drop table if exists pelanggan cascade;

create table pelanggan (
  id uuid primary key default gen_random_uuid(),
  kode_pelanggan varchar(12) not null unique,
  nama varchar(120) not null,
  no_telepon varchar(25) not null,
  email varchar(150),
  alamat text not null,
  status varchar(12) not null default 'aktif' check (status in ('aktif', 'nonaktif')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table kendaraan (
  id uuid primary key default gen_random_uuid(),
  pelanggan_id uuid not null references pelanggan(id) on delete restrict,
  nomor_polisi varchar(15) not null unique,
  merk varchar(50) not null,
  tipe varchar(50) not null,
  tahun smallint not null check (tahun between 1990 and extract(year from current_date)::smallint + 1),
  warna varchar(30),
  nomor_rangka varchar(40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, pelanggan_id)
);

create table layanan (
  id uuid primary key default gen_random_uuid(),
  kode_layanan varchar(12) not null unique,
  nama_layanan varchar(120) not null,
  kategori varchar(40) not null check (kategori in ('body repair', 'pengecatan', 'detailing', 'tambahan')),
  deskripsi text,
  estimasi_jam numeric(4,1) not null default 1 check (estimasi_jam > 0),
  harga_standar numeric(14,2) not null check (harga_standar >= 0),
  aktif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function buat_nomor_transaksi()
returns varchar
language plpgsql
as $$
begin
  return 'TRX-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || upper(substr(gen_random_uuid()::text, 1, 4));
end;
$$;

create table pendapatan (
  id uuid primary key default gen_random_uuid(),
  nomor_transaksi varchar(35) not null unique default buat_nomor_transaksi(),
  pelanggan_id uuid not null references pelanggan(id) on delete restrict,
  kendaraan_id uuid not null,
  layanan_id uuid not null references layanan(id) on delete restrict,
  tanggal date not null default current_date,
  subtotal numeric(14,2) not null check (subtotal >= 0),
  diskon numeric(14,2) not null default 0 check (diskon >= 0),
  total numeric(14,2) generated always as (subtotal - diskon) stored check (total > 0),
  metode_pembayaran varchar(15) not null default 'tunai' check (metode_pembayaran in ('tunai', 'transfer', 'qris', 'debit')),
  status_pembayaran varchar(15) not null default 'lunas' check (status_pembayaran in ('lunas', 'menunggu', 'dibatalkan')),
  catatan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (kendaraan_id, pelanggan_id) references kendaraan(id, pelanggan_id) on delete restrict
);

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger pelanggan_updated_at before update on pelanggan for each row execute function set_updated_at();
create trigger kendaraan_updated_at before update on kendaraan for each row execute function set_updated_at();
create trigger layanan_updated_at before update on layanan for each row execute function set_updated_at();
create trigger pendapatan_updated_at before update on pendapatan for each row execute function set_updated_at();

create index idx_pelanggan_status on pelanggan(status);
create index idx_kendaraan_pelanggan on kendaraan(pelanggan_id);
create index idx_kendaraan_nomor_polisi on kendaraan(lower(nomor_polisi));
create index idx_layanan_kategori on layanan(kategori);
create index idx_layanan_aktif on layanan(aktif);
create index idx_pendapatan_tanggal on pendapatan(tanggal desc);
create index idx_pendapatan_pelanggan on pendapatan(pelanggan_id);
create index idx_pendapatan_layanan on pendapatan(layanan_id);
create index idx_pendapatan_status on pendapatan(status_pembayaran);

create view laporan_pendapatan as
select
  p.id,
  p.nomor_transaksi,
  p.tanggal,
  pl.kode_pelanggan,
  pl.nama as nama_pelanggan,
  k.nomor_polisi,
  k.merk || ' ' || k.tipe as kendaraan,
  l.kode_layanan,
  l.nama_layanan,
  l.kategori,
  p.subtotal,
  p.diskon,
  p.total,
  p.metode_pembayaran,
  p.status_pembayaran,
  p.catatan
from pendapatan p
join pelanggan pl on pl.id = p.pelanggan_id
join kendaraan k on k.id = p.kendaraan_id
join layanan l on l.id = p.layanan_id;

alter table pelanggan enable row level security;
alter table kendaraan enable row level security;
alter table layanan enable row level security;
alter table pendapatan enable row level security;

create policy "public read pelanggan" on pelanggan for select to anon using (true);
create policy "public read kendaraan" on kendaraan for select to anon using (true);
create policy "public read layanan" on layanan for select to anon using (aktif = true);
create policy "public read pendapatan" on pendapatan for select to anon using (true);
create policy "public insert pelanggan" on pelanggan for insert to anon with check (true);
create policy "public insert kendaraan" on kendaraan for insert to anon with check (true);
create policy "public insert layanan" on layanan for insert to anon with check (true);
create policy "public insert pendapatan" on pendapatan for insert to anon with check (true);

insert into pelanggan (kode_pelanggan, nama, no_telepon, email, alamat) values
  ('PLG-0001', 'Budi Santoso', '081234567890', 'budi@email.com', 'Jl. Merdeka No. 12'),
  ('PLG-0002', 'Siti Rahma', '082112223333', 'siti@email.com', 'Jl. Mawar No. 8'),
  ('PLG-0003', 'Andi Wijaya', '085677889900', 'andi@email.com', 'Jl. Kenanga No. 4'),
  ('PLG-0004', 'Rina Maharani', '081298765432', 'rina@email.com', 'Jl. Melati No. 17'),
  ('PLG-0005', 'Fajar Nugroho', '087711223344', 'fajar@email.com', 'Jl. Rajawali No. 21'),
  ('PLG-0006', 'Dewi Lestari', '083812345678', 'dewi@email.com', 'Jl. Anggrek No. 3'),
  ('PLG-0007', 'Rizky Ramadhan', '089512345678', 'rizky@email.com', 'Jl. Cempaka No. 9'),
  ('PLG-0008', 'Maya Putri', '081355667788', 'maya@email.com', 'Jl. Diponegoro No. 31'),
  ('PLG-0009', 'Yoga Pratama', '082233445566', 'yoga@email.com', 'Jl. Sawo No. 10'),
  ('PLG-0010', 'Nadia Permata', '085234567891', 'nadia@email.com', 'Jl. Pahlawan No. 5'),
  ('PLG-0011', 'Teguh Haryanto', '081977665544', 'teguh@email.com', 'Jl. Mangga No. 15'),
  ('PLG-0012', 'Lukman Hakim', '088812345678', 'lukman@email.com', 'Jl. Kamboja No. 2');

insert into kendaraan (pelanggan_id, nomor_polisi, merk, tipe, tahun, warna, nomor_rangka)
select p.id, d.nomor_polisi, d.merk, d.tipe, d.tahun, d.warna, d.nomor_rangka
from pelanggan p join (values
  ('PLG-0001', 'B 1234 PB', 'Honda', 'Vario 160', 2023, 'Hitam', 'MH1KZAA123456001'),
  ('PLG-0002', 'B 5678 SR', 'Yamaha', 'NMAX', 2022, 'Merah', 'MH3SGAA223456002'),
  ('PLG-0003', 'B 9012 AW', 'Honda', 'CBR 150R', 2021, 'Putih', 'MH1KZAA323456003'),
  ('PLG-0004', 'B 2468 RM', 'Yamaha', 'Fazzio', 2023, 'Hijau', 'MH3SGAA423456004'),
  ('PLG-0005', 'B 1357 FN', 'Kawasaki', 'Ninja 250', 2020, 'Hijau', 'MH4EXAA523456005'),
  ('PLG-0006', 'B 8642 DL', 'Honda', 'Scoopy', 2022, 'Cream', 'MH1KZAA623456006'),
  ('PLG-0007', 'B 7788 RR', 'Suzuki', 'GSX-R150', 2021, 'Biru', 'MH8DLAA723456007'),
  ('PLG-0008', 'B 4455 MP', 'Vespa', 'Sprint 150', 2022, 'Kuning', 'ZAPMABA823456008'),
  ('PLG-0009', 'B 1122 YP', 'Honda', 'Beat', 2020, 'Biru', 'MH1KZAA923456009'),
  ('PLG-0010', 'B 3344 NP', 'Yamaha', 'Aerox', 2023, 'Abu-abu', 'MH3SGAA023456010'),
  ('PLG-0011', 'B 5566 TH', 'Honda', 'ADV 160', 2024, 'Hitam', 'MH1KZAA123456011'),
  ('PLG-0012', 'B 9900 LH', 'Royal Enfield', 'Classic 350', 2021, 'Silver', 'ME3J3AA223456012')
) as d(kode_pelanggan, nomor_polisi, merk, tipe, tahun, warna, nomor_rangka) on p.kode_pelanggan = d.kode_pelanggan;

insert into layanan (kode_layanan, nama_layanan, kategori, deskripsi, estimasi_jam, harga_standar) values
  ('LYN-0001', 'Press Body Ringan', 'body repair', 'Perbaikan penyok ringan pada panel bodi', 2, 150000),
  ('LYN-0002', 'Press Body Berat', 'body repair', 'Perbaikan panel bodi dengan kerusakan berat', 5, 350000),
  ('LYN-0003', 'Ganti Panel Body', 'body repair', 'Pelepasan dan penggantian panel bodi', 3, 450000),
  ('LYN-0004', 'Cat Ulang Panel', 'pengecatan', 'Pengecatan ulang satu panel bodi motor', 4, 250000),
  ('LYN-0005', 'Cat Full Body', 'pengecatan', 'Pengecatan seluruh bagian bodi motor', 12, 1200000),
  ('LYN-0006', 'Poles dan Detailing', 'detailing', 'Perawatan tampilan dan poles bodi', 3, 120000),
  ('LYN-0007', 'Coating Body', 'detailing', 'Pelapisan pelindung cat bodi', 5, 500000),
  ('LYN-0008', 'Pemasangan Stiker', 'tambahan', 'Pemasangan stiker custom atau standar', 2, 180000),
  ('LYN-0009', 'Cuci Motor Premium', 'tambahan', 'Cuci detail dengan sampo dan pengeringan', 1, 50000);

insert into pendapatan (pelanggan_id, kendaraan_id, layanan_id, tanggal, subtotal, diskon, metode_pembayaran, status_pembayaran, catatan)
select pl.id, k.id, l.id, d.tanggal::date, d.subtotal, d.diskon, d.metode_pembayaran, d.status_pembayaran, d.catatan
from (values
  ('PLG-0001', 'B 1234 PB', 'LYN-0001', '2026-09-23', 150000, 0, 'qris', 'lunas', 'Penyok bagian kanan'),
  ('PLG-0002', 'B 5678 SR', 'LYN-0004', '2026-09-22', 250000, 25000, 'transfer', 'lunas', 'Warna merah glossy'),
  ('PLG-0003', 'B 9012 AW', 'LYN-0002', '2026-09-21', 350000, 0, 'tunai', 'lunas', 'Panel depan rusak'),
  ('PLG-0004', 'B 2468 RM', 'LYN-0006', '2026-09-20', 120000, 0, 'debit', 'lunas', null),
  ('PLG-0005', 'B 1357 FN', 'LYN-0005', '2026-09-19', 1200000, 100000, 'transfer', 'lunas', 'Paket full body'),
  ('PLG-0006', 'B 8642 DL', 'LYN-0001', '2026-09-18', 150000, 0, 'tunai', 'lunas', null),
  ('PLG-0007', 'B 7788 RR', 'LYN-0007', '2026-09-17', 500000, 50000, 'qris', 'lunas', 'Coating setelah repaint'),
  ('PLG-0008', 'B 4455 MP', 'LYN-0004', '2026-09-16', 250000, 0, 'transfer', 'lunas', null),
  ('PLG-0009', 'B 1122 YP', 'LYN-0009', '2026-09-15', 50000, 0, 'tunai', 'lunas', null),
  ('PLG-0010', 'B 3344 NP', 'LYN-0003', '2026-09-14', 450000, 0, 'debit', 'lunas', 'Panel samping pecah'),
  ('PLG-0011', 'B 5566 TH', 'LYN-0008', '2026-09-13', 180000, 0, 'qris', 'lunas', null),
  ('PLG-0012', 'B 9900 LH', 'LYN-0002', '2026-09-12', 350000, 25000, 'transfer', 'lunas', 'Penyok tangki'),
  ('PLG-0001', 'B 1234 PB', 'LYN-0006', '2026-09-05', 120000, 0, 'tunai', 'lunas', null),
  ('PLG-0003', 'B 9012 AW', 'LYN-0004', '2026-09-03', 250000, 0, 'qris', 'lunas', null),
  ('PLG-0005', 'B 1357 FN', 'LYN-0001', '2026-08-28', 150000, 0, 'tunai', 'lunas', null),
  ('PLG-0008', 'B 4455 MP', 'LYN-0007', '2026-08-23', 500000, 50000, 'transfer', 'lunas', null),
  ('PLG-0010', 'B 3344 NP', 'LYN-0006', '2026-08-18', 120000, 0, 'debit', 'lunas', null),
  ('PLG-0002', 'B 5678 SR', 'LYN-0008', '2026-08-10', 180000, 0, 'qris', 'lunas', null),
  ('PLG-0006', 'B 8642 DL', 'LYN-0009', '2026-07-29', 50000, 0, 'tunai', 'lunas', null),
  ('PLG-0011', 'B 5566 TH', 'LYN-0001', '2026-07-20', 150000, 0, 'transfer', 'lunas', null),
  ('PLG-0004', 'B 2468 RM', 'LYN-0004', '2026-07-12', 250000, 0, 'qris', 'lunas', null),
  ('PLG-0007', 'B 7788 RR', 'LYN-0002', '2026-06-25', 350000, 0, 'debit', 'lunas', null),
  ('PLG-0009', 'B 1122 YP', 'LYN-0006', '2026-06-18', 120000, 0, 'tunai', 'lunas', null),
  ('PLG-0012', 'B 9900 LH', 'LYN-0005', '2026-06-05', 1200000, 100000, 'transfer', 'lunas', 'Paket restorasi'),
  ('PLG-0001', 'B 1234 PB', 'LYN-0009', '2026-05-28', 50000, 0, 'qris', 'lunas', null)
) as d(kode_pelanggan, nomor_polisi, kode_layanan, tanggal, subtotal, diskon, metode_pembayaran, status_pembayaran, catatan)
join pelanggan pl on pl.kode_pelanggan = d.kode_pelanggan
join kendaraan k on k.nomor_polisi = d.nomor_polisi and k.pelanggan_id = pl.id
join layanan l on l.kode_layanan = d.kode_layanan;
