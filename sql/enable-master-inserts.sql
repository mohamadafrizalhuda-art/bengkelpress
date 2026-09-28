-- Jalankan di Supabase SQL Editor. Aman dijalankan berulang kali.
-- Tidak menghapus data history.

grant usage on schema public to anon, authenticated;
grant select, insert on table public.pelanggan, public.kendaraan, public.layanan, public.pendapatan to anon, authenticated;

drop policy if exists "public insert pelanggan" on public.pelanggan;
drop policy if exists "public insert kendaraan" on public.kendaraan;
drop policy if exists "public insert layanan" on public.layanan;
drop policy if exists "public insert pendapatan" on public.pendapatan;

create policy "public insert pelanggan" on public.pelanggan
  for insert to anon, authenticated with check (true);
create policy "public insert kendaraan" on public.kendaraan
  for insert to anon, authenticated with check (true);
create policy "public insert layanan" on public.layanan
  for insert to anon, authenticated with check (true);
create policy "public insert pendapatan" on public.pendapatan
  for insert to anon, authenticated with check (true);
