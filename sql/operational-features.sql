-- Jalankan sekali di Supabase SQL Editor untuk fitur booking, antrean, kasir, dan laporan.
-- Tidak menghapus tabel atau data yang sudah ada.

create sequence if not exists public.nomor_tiket_seq;

create table if not exists public.antrian_servis (
  id uuid primary key default gen_random_uuid(),
  nomor_tiket varchar(16) not null unique default ('PB-' || lpad(nextval('public.nomor_tiket_seq')::text, 4, '0')),
  tipe_kedatangan varchar(10) not null default 'walk-in' check (tipe_kedatangan in ('booking', 'walk-in')),
  pelanggan_id uuid not null references public.pelanggan(id) on delete restrict,
  kendaraan_id uuid not null,
  layanan_id uuid not null references public.layanan(id) on delete restrict,
  jadwal_mulai timestamptz not null default now(),
  waktu_mulai timestamptz,
  waktu_selesai timestamptz,
  status varchar(12) not null default 'menunggu' check (status in ('menunggu', 'dikerjakan', 'selesai', 'dipanggil')),
  catatan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint antrian_kendaraan_milik_pelanggan foreign key (kendaraan_id, pelanggan_id) references public.kendaraan(id, pelanggan_id) on delete restrict
);

grant usage on schema public to anon, authenticated;
grant usage, select on sequence public.nomor_tiket_seq to anon, authenticated;
grant select, insert, update on table public.antrian_servis to anon, authenticated;
grant select, insert on table public.pendapatan to anon, authenticated;

alter table public.pendapatan add column if not exists antrian_id uuid references public.antrian_servis(id) on delete set null;
create unique index if not exists idx_pendapatan_antrian_unique on public.pendapatan(antrian_id) where antrian_id is not null;
create index if not exists idx_antrian_jadwal on public.antrian_servis(jadwal_mulai);
create index if not exists idx_antrian_status on public.antrian_servis(status);
create index if not exists idx_antrian_tipe_status on public.antrian_servis(tipe_kedatangan, status);

alter table public.antrian_servis enable row level security;
drop policy if exists "public read antrian" on public.antrian_servis;
drop policy if exists "public insert antrian" on public.antrian_servis;
drop policy if exists "public update antrian" on public.antrian_servis;
create policy "public read antrian" on public.antrian_servis for select to anon, authenticated using (true);
create policy "public insert antrian" on public.antrian_servis for insert to anon, authenticated with check (true);
create policy "public update antrian" on public.antrian_servis for update to anon, authenticated using (true) with check (true);

create or replace function public.set_antrian_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  if new.status = 'dikerjakan' and old.status is distinct from 'dikerjakan' then
    new.waktu_mulai = coalesce(new.waktu_mulai, now());
  end if;
  if new.status in ('selesai', 'dipanggil') and old.status not in ('selesai', 'dipanggil') then
    new.waktu_selesai = coalesce(new.waktu_selesai, now());
  end if;
  return new;
end;
$$;
drop trigger if exists antrian_updated_at on public.antrian_servis;
create trigger antrian_updated_at before update on public.antrian_servis for each row execute function public.set_antrian_updated_at();
