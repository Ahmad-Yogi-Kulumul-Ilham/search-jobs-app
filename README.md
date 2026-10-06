# Pencari Kerja Remote

Aplikasi desktop Windows untuk mencari lowongan kerja remote dari beberapa situs sekaligus. Lowongan dikumpulkan ke satu daftar, disimpan di komputer sendiri, dan bisa dicari tanpa membuka tiap situs satu per satu.

## Fitur saat ini

- Mengambil lowongan dari Remote OK, Jobicy, We Work Remotely, dan Remotive.
- Menambah sumber sendiri: feed RSS, atau halaman karier perusahaan di Greenhouse, Lever, dan Ashby (hanya lowongan remote yang diambil).
- Pencarian berdasarkan posisi, perusahaan, lokasi, kategori, atau keahlian.
- Filter: bisa dilamar dari Indonesia, ada info gaji, jenis kerja, dan sumber.
- Gaji dikonversi ke perkiraan Rupiah per bulan (kurs harian Bank Sentral Eropa lewat Frankfurter).
- Perkiraan jam kerja dalam WIB untuk lowongan yang terbatas di wilayah tertentu.
- Pelacak lamaran: Disimpan, Dilamar, Interview, Tawaran, Ditolak, lengkap dengan catatan dan jadwal interview. Lamaran dari situs lain bisa ditambahkan manual.
- Sembunyikan lowongan dan blokir perusahaan.
- Data tersimpan lokal (SQLite), jadi daftar terakhir tetap bisa dibuka tanpa internet.
- Pembaruan otomatis saat aplikasi dibuka jika data sudah lebih dari 6 jam.

Label "Bisa dari Indonesia" dinilai dari lokasi yang tertulis di lowongan. Deskripsi lowongan bisa saja menambahkan syarat lain, jadi tetap periksa sebelum melamar.

## Struktur

| Folder | Isi |
| --- | --- |
| `backend/` | Paket Dart murni: pengambil data tiap sumber, database lokal, dan pencarian. Tidak bergantung pada Flutter. |
| `frontend/` | Aplikasi Flutter untuk Windows: tampilan daftar dan detail lowongan. Memakai `backend/` sebagai dependensi. |

Ini aplikasi desktop tanpa server. "Backend" di sini adalah lapisan data dan logika yang berjalan di dalam aplikasi yang sama.

## Menjalankan

Yang dibutuhkan:

- Flutter 3.47 atau lebih baru.
- Visual Studio 2022 (atau Build Tools) dengan komponen "Desktop development with C++".
- Developer Mode Windows aktif (Settings → System → For developers).

```
cd frontend
flutter pub get
flutter run -d windows
```

Untuk membuat versi rilis:

```
flutter build windows --release --no-tree-shake-icons
```

Hasilnya ada di `frontend/build/windows/x64/runner/Release/`. Opsi `--no-tree-shake-icons` wajib: tanpa itu, Flutter 3.47 membuang sebagian ikon dari build rilis sehingga tombol dan menu tampil tanpa ikon.

Jika Smart App Control Windows aktif, hasil build yang belum ditandatangani bisa diblokir ("An Application Control policy has blocked this file"). Versi debug lewat `flutter run -d windows` juga bisa terkena. Ini perlindungan Windows, bukan kesalahan aplikasi.

## Tes

```
cd backend
dart pub get
dart test

cd ../frontend
flutter test
```

## Sumber data

Lowongan berasal dari API dan feed publik [Remote OK](https://remoteok.com), [Jobicy](https://jobicy.com), [We Work Remotely](https://weworkremotely.com), dan [Remotive](https://remotive.com). Setiap lowongan menampilkan sumbernya, dan tombol lamar selalu membuka halaman lowongan di situs asalnya. Aplikasi membatasi seberapa sering tiap sumber diambil sesuai ketentuan masing-masing.

## Rencana berikutnya

1. Notifikasi lowongan baru, pengingat tindak lanjut, dan peringatan lowongan mencurigakan.
2. Unggah CV dan review kecocokan dengan AI.
3. Bantuan mengisi formulir lamaran.
