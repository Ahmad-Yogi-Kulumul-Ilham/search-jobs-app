# Pencari Kerja Remote

Aplikasi desktop Windows untuk mencari lowongan kerja remote dari beberapa situs sekaligus. Lowongan dikumpulkan ke satu daftar, disimpan di komputer sendiri, dan bisa dicari tanpa membuka tiap situs satu per satu.

## Fitur saat ini

- Mengambil lowongan dari Remote OK, Jobicy, We Work Remotely, dan Remotive.
- Menambah sumber sendiri: feed RSS, atau halaman karier perusahaan di Greenhouse, Lever, dan Ashby (hanya lowongan remote yang diambil).
- Temukan sumber: daftar sumber pilihan, plus pencarian sumber baru. "Cari dari lowongan" (gratis) memeriksa apakah perusahaan di lowongan yang sudah masuk punya halaman karier di Greenhouse, Lever, atau Ashby, 40 perusahaan per klik. "Cari dengan AI" mencari situs dan perusahaan baru di web memakai AI yang dipilih di Pengaturan. Setiap temuan diambil sekali untuk dicek sebelum ditampilkan; centang yang mau ditambahkan.
- Pencarian berdasarkan posisi, perusahaan, lokasi, kategori, atau keahlian.
- Filter: bisa dilamar dari Indonesia, ada info gaji, jenis kerja, dan sumber.
- Gaji dikonversi ke perkiraan Rupiah per bulan (kurs harian Bank Sentral Eropa lewat Frankfurter).
- Perkiraan jam kerja dalam WIB untuk lowongan yang terbatas di wilayah tertentu.
- Pelacak lamaran: Disimpan, Dilamar, Interview, Tawaran, Ditolak, lengkap dengan catatan dan jadwal interview. Lamaran dari situs lain bisa ditambahkan manual.
- Sembunyikan lowongan dan blokir perusahaan.
- Pencarian tersimpan: notifikasi desktop saat ada lowongan baru yang cocok.
- Pengingat follow-up (7 hari tanpa kabar setelah melamar) dan interview dalam 24 jam, di aplikasi dan lewat notifikasi.
- Peringatan lowongan mencurigakan: meminta bayaran, kontak hanya lewat Telegram/WhatsApp, pembayaran lewat kripto atau kartu hadiah, janji penghasilan besar, email rekrutmen pribadi, atau tanpa nama perusahaan.
- CV: unggah beberapa versi (PDF atau DOCX).
- Review AI dengan Claude, ChatGPT, Gemini, atau model lain lewat OpenRouter: skor kecocokan CV dengan lowongan, kekuatan, kekurangan, kata kunci yang hilang, saran penulisan ulang yang bisa disalin, dan cek apakah lowongan menerima pelamar dari Indonesia. Skor tampil di daftar lowongan.
- Draf cover letter dan bank jawaban untuk pertanyaan formulir yang sering muncul, dengan draf dari AI.
- Bantuan mengisi formulir lamaran: halaman lamaran dibuka di browser dalam aplikasi (WebView2), lalu "Isi otomatis" mengisi data diri, melampirkan CV, dan mendaftar pertanyaan yang belum terjawab beserta jawaban dari bank jawaban atau draf AI. Paling cocok untuk formulir Greenhouse, Lever, dan Ashby. Aplikasi tidak pernah menekan tombol kirim; Anda memeriksa lalu mengirim sendiri, kemudian menandainya "Dilamar".
- Data tersimpan lokal (SQLite), jadi daftar terakhir tetap bisa dibuka tanpa internet.
- Pembaruan otomatis saat aplikasi dibuka dan setiap 30 menit selama terbuka, untuk sumber yang datanya sudah lebih dari 6 jam.

Notifikasi Windows hanya muncul untuk aplikasi yang ada di Start menu, jadi saat pertama dijalankan aplikasi membuat pintasan "Pencari Kerja Remote" di Start menu.

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

## Fitur AI

Di Pengaturan, pilih penyedia AI lalu masukkan API key-nya. API key berbeda dari langganan seperti Claude Pro, ChatGPT Plus, atau Gemini Advanced; biaya dihitung per pemakaian dan ditampilkan setelah setiap review. Tiap penyedia punya key sendiri, disimpan terenkripsi dengan Windows DPAPI, jadi hanya akun Windows Anda di komputer ini yang bisa membukanya.

| Penyedia | API key dari | Model |
| --- | --- | --- |
| Claude (Anthropic) | [console.anthropic.com](https://console.anthropic.com) | Opus 5.5 (bawaan), Sonnet 5.5, Haiku 4.5 |
| ChatGPT (OpenAI) | [platform.openai.com](https://platform.openai.com) | GPT-6 Astra, GPT-6.1 Sol, GPT-6 Luna |
| Gemini (Google) | [aistudio.google.com](https://aistudio.google.com) | Gemini 3.1 Pro (preview), 3.8 Flash, 3.1 Flash-Lite |
| OpenRouter | [openrouter.ai](https://openrouter.ai) | Model apa saja yang bisa menjawab dalam format JSON, misalnya DeepSeek, Llama, Qwen, atau Mistral. Isi ID modelnya, seperti `deepseek/deepseek-chat`. |

Biaya untuk Claude, ChatGPT, dan Gemini diperkirakan dari jumlah token dan harga resmi per Oktober 2026; biaya OpenRouter diambil dari tagihannya sendiri. Gemini punya kuota gratis, tetapi Google dapat memakai data dari kuota gratis untuk meningkatkan layanannya.

Setiap review mengirim CV dan teks lowongan ke penyedia yang dipilih. AI diminta hanya menyusun ulang isi CV, tidak menambah pengalaman yang tidak ada.

## Batasan yang diketahui

- Fitur AI sudah diuji dengan server tiruan untuk semua penyedia, belum dengan API key asli.
- Pengisi formulir diuji di Chromium dengan formulir contoh yang meniru Greenhouse, Lever, dan Ashby. Formulir asli bisa berbeda dan berubah sewaktu-waktu, jadi selalu periksa hasilnya sebelum mengirim.
- Lowongan dari situs agregator (Remote OK, We Work Remotely, dan sebagainya) sering mengarah ke halaman perusahaan dengan formulir yang beragam. Di sana pengisian otomatis bisa sebagian saja.
