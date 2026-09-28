const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Konfigurasi project Supabase.
const SUPABASE_URL = 'https://gvwcgmdmbpdsjmjjutjc.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_OBTjeHcZjhrPD4H39PSC-Q_j_6cnMsh';
const PORT = 3000;
const FRONTEND_DIR = path.join(__dirname, '..', 'frontend');
const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' };

async function supabaseRequest(table, options = {}) {
  const endpoint = `${SUPABASE_URL}/rest/v1/${table}${options.query || ''}`;
  const requestOptions = { ...options };
  delete requestOptions.query;
  const response = await fetch(endpoint, { ...requestOptions, headers: { apikey: SUPABASE_PUBLISHABLE_KEY, Authorization: `Bearer ${SUPABASE_PUBLISHABLE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=representation', ...(options.headers || {}) } });
  const text = await response.text();
  if (!response.ok) throw new Error(text || `Supabase error ${response.status}`);
  return text ? JSON.parse(text) : [];
}
function send(response, status, data) { response.writeHead(status, headers); response.end(JSON.stringify(data)); }
function readBody(request) { return new Promise((resolve, reject) => { let body = ''; request.on('data', chunk => { body += chunk; if (body.length > 100000) reject(new Error('Payload terlalu besar')); }); request.on('end', () => { try { resolve(JSON.parse(body || '{}')); } catch { reject(new Error('JSON tidak valid')); } }); request.on('error', reject); }); }
async function handleApi(request, response, url) {
  const table = url.pathname.split('/')[2];
  const allowed = ['pelanggan', 'kendaraan', 'layanan', 'pendapatan', 'antrian'];
  if (table === 'antrian' && request.method === 'GET') { const query = '?select=*,pelanggan(id,nama,no_telepon),kendaraan(id,nomor_polisi,merk,tipe),layanan(id,nama_layanan,estimasi_jam,harga_standar)&order=jadwal_mulai.asc'; return send(response, 200, await supabaseRequest('antrian_servis', { method: 'GET', headers: { Accept: 'application/json' }, query })); }
  if (table === 'antrian' && request.method === 'POST') { const body = await readBody(request); if (!body.pelanggan_id || !body.kendaraan_id || !body.layanan_id || !body.jadwal_mulai) return send(response, 400, { error: 'Pelanggan, kendaraan, layanan, dan jadwal wajib diisi' }); const payload = { tipe_kedatangan: body.tipe_kedatangan === 'booking' ? 'booking' : 'walk-in', pelanggan_id: body.pelanggan_id, kendaraan_id: body.kendaraan_id, layanan_id: body.layanan_id, jadwal_mulai: body.jadwal_mulai, catatan: body.catatan || null }; return send(response, 201, await supabaseRequest('antrian_servis', { method: 'POST', body: JSON.stringify(payload) })); }
  if (table === 'antrian' && request.method === 'PATCH') { const id = url.pathname.split('/')[3]; const body = await readBody(request); if (!id || !['menunggu', 'dikerjakan', 'selesai', 'dipanggil'].includes(body.status)) return send(response, 400, { error: 'ID antrean atau status tidak valid' }); const result = await supabaseRequest(`antrian_servis?id=eq.${encodeURIComponent(id)}`, { method: 'PATCH', body: JSON.stringify({ status: body.status }) }); return send(response, 200, result); }
  if (!allowed.includes(table)) return send(response, 404, { error: 'Endpoint tidak ditemukan' });
  if (request.method === 'GET') { const orderColumn = { pelanggan: 'nama', kendaraan: 'nomor_polisi', layanan: 'nama_layanan' }[table]; const query = table === 'pendapatan' ? '?select=*,pelanggan(nama),layanan(nama_layanan)&order=tanggal.desc,created_at.desc' : `?select=*&order=${orderColumn}.asc`; return send(response, 200, await supabaseRequest(table, { method: 'GET', headers: { Accept: 'application/json' }, query })); }
  if (request.method === 'POST' && ['pelanggan', 'kendaraan', 'layanan'].includes(table)) { const body = await readBody(request); const code = prefix => `${prefix}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`; let payload; if (table === 'pelanggan') { if (!body.nama || !body.no_telepon || !body.alamat) return send(response, 400, { error: 'Nama, nomor telepon, dan alamat pelanggan wajib diisi' }); payload = { kode_pelanggan: code('PLG'), nama: body.nama, no_telepon: body.no_telepon, email: body.email || null, alamat: body.alamat, status: 'aktif' }; } if (table === 'kendaraan') { if (!body.pelanggan_id || !body.nomor_polisi || !body.merk || !body.tipe || !body.tahun) return send(response, 400, { error: 'Pelanggan, nomor polisi, merk, tipe, dan tahun kendaraan wajib diisi' }); payload = { pelanggan_id: body.pelanggan_id, nomor_polisi: body.nomor_polisi.toUpperCase(), merk: body.merk, tipe: body.tipe, tahun: Number(body.tahun), warna: body.warna || null }; } if (table === 'layanan') { if (!body.nama_layanan || !body.kategori || !body.harga_standar || !body.estimasi_jam) return send(response, 400, { error: 'Nama, kategori, harga, dan estimasi layanan wajib diisi' }); payload = { kode_layanan: code('LYN'), nama_layanan: body.nama_layanan, kategori: body.kategori, deskripsi: body.deskripsi || null, estimasi_jam: Number(body.estimasi_jam), harga_standar: Number(body.harga_standar), aktif: true }; } return send(response, 201, await supabaseRequest(table, { method: 'POST', body: JSON.stringify(payload) })); }
  if (request.method === 'POST' && table === 'pendapatan') { const body = await readBody(request); if (!body.pelanggan_id || !body.kendaraan_id || !body.layanan_id || !body.total || !body.tanggal) return send(response, 400, { error: 'Semua kolom transaksi wajib diisi' }); const payload = { ...body, subtotal: Number(body.total), diskon: Number(body.diskon || 0), metode_pembayaran: body.metode_pembayaran || 'tunai' }; delete payload.total; if (!payload.antrian_id) delete payload.antrian_id; return send(response, 201, await supabaseRequest(table, { method: 'POST', body: JSON.stringify(payload) })); }
  return send(response, 405, { error: 'Method tidak diizinkan' });
}
function serveStatic(request, response, url) { const requested = url.pathname === '/' ? '/index.html' : url.pathname; const filePath = path.normalize(path.join(FRONTEND_DIR, requested)); if (!filePath.startsWith(FRONTEND_DIR) || !fs.existsSync(filePath)) return send(response, 404, { error: 'File tidak ditemukan' }); const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8' }; response.writeHead(200, { 'Content-Type': types[path.extname(filePath)] || 'application/octet-stream' }); fs.createReadStream(filePath).pipe(response); }
const server = http.createServer(async (request, response) => { const url = new URL(request.url, `http://${request.headers.host}`); try { if (request.method === 'OPTIONS') { response.writeHead(204, headers); return response.end(); } if (url.pathname === '/api/health') return send(response, 200, { status: 'ok' }); if (url.pathname.startsWith('/api/')) return await handleApi(request, response, url); serveStatic(request, response, url); } catch (error) { send(response, 500, { error: error.message }); } });
server.listen(PORT, () => console.log(`Press Body Motor berjalan di http://localhost:${PORT}`));
