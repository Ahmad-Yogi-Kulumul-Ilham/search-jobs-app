# Pencari Kerja Remote

Aplikasi desktop Windows untuk mencari lowongan kerja remote dari beberapa situs sekaligus. Lowongan dikumpulkan ke satu daftar, disimpan di komputer sendiri, dan bisa dicari tanpa membuka tiap situs satu per satu.

## Fitur saat ini

- Mengambil lowongan dari Remote OK, Jobicy, We Work Remotely, dan Remotive.
- Pencarian berdasarkan posisi, perusahaan, lokasi, kategori, atau keahlian.
- Filter per sumber.
- Detail lowongan dengan tombol untuk melamar di halaman aslinya.
- Data tersimpan lokal (SQLite), jadi daftar terakhir tetap bisa dibuka tanpa internet.
- Pembaruan otomatis saat aplikasi dibuka jika data sudah lebih dari 6 jam.

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

Untuk membuat versi rilis: `flutter build windows --release`. Hasilnya ada di `frontend/build/windows/x64/runner/Release/`.

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

1. Filter lengkap (termasuk lowongan yang menerima pelamar dari Indonesia), tandai lowongan, pelacak lamaran, dan pengaturan sumber.
2. Notifikasi lowongan baru dan pengingat tindak lanjut.
3. Unggah CV dan review kecocokan dengan AI.
4. Bantuan mengisi formulir lamaran.
