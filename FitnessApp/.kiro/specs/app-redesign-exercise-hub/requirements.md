# Requirements Document

## Introduction

Dokumen ini mendefinisikan kebutuhan untuk redesign UI/UX skala besar pada aplikasi iOS "PULSE — AI Fitness Coach" sekaligus penambahan beberapa fitur baru yang memanfaatkan **ExerciseDB** (open exercise database API: ribuan latihan dengan demo GIF, target muscle, secondary muscles, body part, equipment, dan instruksi langkah-demi-langkah).

Redesign berfokus pada **layout, hierarki visual, komponen, motion, dan polish** — *bukan* perubahan warna. Palet merek yang ada (Strava orange `#FC4C02` primary, warm amber secondary, deep coral accent, dan latar pure-black dark-first) dipertahankan persis seperti yang didefinisikan di `Color+Theme.swift`. Hasil akhir harus terasa *hand-crafted* dan disengaja, dengan kepadatan konten nyata, spasi yang bertujuan, dan identitas atletik yang energetik dan khas — bukan tampilan generik "AI-generated".

Fitur baru yang dicakup: Exercise Library/Explorer, Workout Builder, Enriched Exercise Detail (tertaut ke fitur camera form-coaching yang sudah ada), Muscle Map/Body Heatmap, Scheduling (jadwal), integrasi AI chat (GLM) ke alur baru, dan redesign visual layar kamera.

Semua fitur baru berjalan di iOS 16.4 (Swift 5.7, SwiftUI), menggunakan `NavigationStack`, pola `@StateObject`/`ObservableObject` + `@Published` (satu ViewModel per layar), Core Data untuk persistensi, dan **tanpa** API iOS 17+.

## Glossary

- **PULSE_App**: Keseluruhan aplikasi iOS "PULSE — AI Fitness Coach" yang sedang diredesign.
- **Design_System**: Kumpulan token desain yang didefinisikan di `FitnessApp/Core/Extensions/Color+Theme.swift`, mencakup `BrandTokens`, semantic `Color` tokens, spacing tokens (`CGFloat.spacing*`), dan corner radius tokens (`CGFloat.cornerRadius*`).
- **Brand_Palette**: Himpunan warna merek tetap — `themePrimary` (#FC4C02), `themeSecondary` (warm amber), `themeAccent` (deep coral), `themeBackground` (pure black pada dark mode), beserta `brandGradient` dan `coachGradient`.
- **Component_Library**: Kumpulan komponen SwiftUI yang dapat dipakai ulang (card, chip/filter, button, badge, section header, list row) yang dibangun di atas Design_System.
- **ExerciseDB_API**: Layanan eksternal ExerciseDB yang menyediakan data latihan (id, name, gifUrl, target, secondaryMuscles, bodyPart, equipment, instructions).
- **ExerciseDB_Service**: Komponen Swift internal yang melakukan permintaan jaringan ke ExerciseDB_API, melakukan decoding, caching, dan penanganan error. Mengekspos `async`/`throws` API ke ViewModel.
- **Exercise_Item**: Model nilai (struct `Codable`) yang merepresentasikan satu latihan dari ExerciseDB_API.
- **Exercise_Cache**: Penyimpanan lokal (Core Data dan/atau on-disk) untuk data Exercise_Item dan aset GIF/gambar agar tersedia secara offline dan mengurangi panggilan jaringan.
- **Library_Screen**: Layar Exercise Library/Explorer untuk menelusuri, mencari, dan memfilter latihan.
- **Detail_Screen**: Layar Enriched Exercise Detail untuk satu Exercise_Item.
- **Builder_Screen**: Layar Workout Builder untuk membuat dan menyimpan rutinitas latihan kustom.
- **Routine**: Rutinitas latihan kustom buatan pengguna yang berisi daftar Routine_Item terurut, disimpan via Core Data.
- **Routine_Item**: Satu entri dalam Routine yang mereferensikan sebuah Exercise_Item beserta target sets, reps, dan rest (detik).
- **Muscle_Map_Screen**: Layar peta otot tubuh interaktif (body heatmap).
- **Body_Region**: Area otot/bagian tubuh yang dapat dipilih pada Muscle_Map_Screen (dipetakan ke nilai `bodyPart`/`target` ExerciseDB).
- **Schedule_Screen**: Layar jadwal/kalender latihan ("jadwal").
- **Scheduled_Workout**: Entri jadwal yang menautkan sebuah Routine ke tanggal/waktu tertentu, disimpan via Core Data.
- **AI_Coach**: Fitur chat bertenaga GLM yang ada (`ChatView` + `GLMService`).
- **Camera_Coaching**: Fitur kamera yang ada (`CameraFeedView` + Vision body-pose analysis) untuk form coaching real-time.
- **App_Router**: `AppRouter` yang mengelola navigasi tab, deep link, dan presentasi kamera.
- **Async_State**: Status tampilan asinkron sebuah layar — salah satu dari `loading`, `loaded`, `empty`, atau `error`.

---

## Requirements

### Requirement 1: Identitas Visual & Tujuan Redesign

**User Story:** As a PULSE user, I want a redesigned interface that feels hand-crafted, energetic, and athletic, so that the app feels premium and distinctive rather than generic.

#### Acceptance Criteria

1. THE PULSE_App SHALL menggunakan seluruh warna merek dari Brand_Palette persis seperti yang didefinisikan di `Color+Theme.swift`, tanpa menambah, menghapus, atau mengubah nilai hex warna merek mana pun.
2. WHERE sebuah view menampilkan warna, THE PULSE_App SHALL mereferensikan semantic `Color` tokens dari Design_System dan SHALL NOT menggunakan nilai hex yang di-hardcode di dalam view.
3. THE PULSE_App SHALL menjadikan dark mode (latar pure-black #000000) sebagai kanvas utama, dengan rasio kontras teks minimal 4.5:1 untuk teks ukuran normal (di bawah 18pt reguler atau di bawah 14pt bold) dan minimal 3:1 untuk teks besar (18pt reguler ke atas atau 14pt bold ke atas) terhadap latar belakang langsungnya, diukur sesuai formula rasio kontras WCAG 2.1.
4. THE PULSE_App SHALL menerapkan spacing antar elemen hanya menggunakan spacing tokens (`spacingSmall`, `spacingMedium`, `spacingLarge`, `spacingExtraLarge`).
5. THE PULSE_App SHALL menerapkan corner radius hanya menggunakan corner radius tokens (`cornerRadiusSmall`, `cornerRadiusLarge`, `cornerRadiusExtraLarge`).
6. WHERE sebuah layar menampilkan branding, THE PULSE_App SHALL menampilkan `BrandTokens.appName`, `BrandTokens.tagline`, dan `BrandTokens.logoSymbol` sebagai sumber tunggal identitas merek.
7. WHEN sebuah transisi layar dipicu, THE PULSE_App SHALL menyelesaikan animasi transisi tersebut dalam rentang 200ms hingga 400ms (inklusif pada kedua batas).

---

### Requirement 2: Component Library yang Dapat Dipakai Ulang

**User Story:** As a developer, I want a shared set of reusable SwiftUI components built on the design tokens, so that screens stay visually consistent and avoid duplicated styling.

#### Acceptance Criteria

1. THE Component_Library SHALL menyediakan komponen yang dapat dipakai ulang untuk minimal: card surface, filter chip, primary button, secondary button, badge, section header, dan list row.
2. THE Component_Library SHALL membangun setiap komponen di atas semantic `Color` tokens, spacing tokens, dan corner radius tokens dari Design_System.
3. THE Component_Library SHALL NOT menggunakan `AnyView`, dan SHALL menggunakan `@ViewBuilder` untuk komposisi kondisional.
4. THE Component_Library SHALL mengekspos setiap komponen interaktif (filter chip, primary button, secondary button) dengan parameter accessibility label dan accessibility identifier yang wajib diisi (non-opsional), dan SHALL merender area ketukan setiap komponen interaktif dengan ukuran minimal 44x44 poin.
5. WHERE sebuah layar baru menampilkan card, chip, atau button, THE PULSE_App SHALL menggunakan komponen dari Component_Library alih-alih mendefinisikan ulang style yang setara.
6. WHILE sebuah primary button atau secondary button berada dalam state disabled, THE Component_Library SHALL NOT memicu aksi tap-nya dan SHALL merender komponen dengan tampilan visual yang berbeda dari state enabled.
7. WHEN sebuah filter chip dipilih atau dibatalkan pemilihannya, THE Component_Library SHALL menampilkan state terpilih dan tidak-terpilih dengan tampilan visual yang berbeda dan SHALL memperbarui accessibility value chip tersebut sesuai state-nya.

---

### Requirement 3: Navigasi & Information Architecture

**User Story:** As a user, I want the new features to be reachable through a clear navigation structure, so that I can find exercises, build workouts, and view my schedule without confusion.

#### Acceptance Criteria

1. THE PULSE_App SHALL mempertahankan tepat kelima tab utama yang ada (Home, Workout, Camera, Calories, More) pada urutan yang sama tanpa menambah atau menghapus tab.
2. THE App_Router SHALL menyediakan rute navigasi menuju Library_Screen, Builder_Screen, Muscle_Map_Screen, dan Schedule_Screen dari dalam aplikasi.
3. WHEN pengguna mengetuk sebuah Exercise_Item pada Library_Screen, THE App_Router SHALL menampilkan Detail_Screen untuk Exercise_Item tersebut menggunakan `NavigationStack` dengan `navigationDestination(for:)`.
4. THE App_Router SHALL menambahkan rute dan/atau deep link baru tanpa menghapus rute `AppTab` yang sudah ada.
5. WHEN pengguna menavigasi mundur dari sebuah layar baru kembali ke Library_Screen, THE App_Router SHALL menampilkan kembali Library_Screen dengan teks pencarian dan seluruh nilai filter aktif yang identik dengan kondisi tepat sebelum pengguna meninggalkan Library_Screen.
6. IF sebuah deep link mereferensikan tab atau rute yang tidak valid, THEN THE App_Router SHALL mempertahankan tab yang sedang dipilih tanpa perubahan, SHALL NOT menambahkan entri apa pun ke navigation stack, dan SHALL NOT melakukan crash.
7. WHEN pengguna memilih tab Camera, THE App_Router SHALL menyajikan Camera_Coaching sebagai full-screen cover yang menutupi seluruh area layar termasuk tab bar.
8. WHEN sebuah deep link yang valid diterima, THE App_Router SHALL menavigasi ke tab atau rute yang direferensikan dan menyelesaikan transisi dalam waktu maksimal 1 detik.

---

### Requirement 4: Integrasi ExerciseDB — Pengambilan & Decoding Data

**User Story:** As a user, I want the app to load exercise data from ExerciseDB, so that I can browse thousands of real exercises with accurate details.

#### Acceptance Criteria

1. WHEN sebuah layar meminta data latihan, THE ExerciseDB_Service SHALL mengambil data dari ExerciseDB_API dan men-decode respons menjadi nilai Exercise_Item menggunakan `Codable`.
2. THE Exercise_Item SHALL mengekspos field: id, name, gifUrl, target muscle, secondaryMuscles, bodyPart, equipment, dan instructions.
3. IF respons ExerciseDB_API tidak dapat di-decode menjadi Exercise_Item, THEN THE ExerciseDB_Service SHALL mengembalikan error deskriptif melalui `Result` atau `throws` tanpa melakukan crash dan tanpa menulis data parsial ke Exercise_Cache.
4. THE ExerciseDB_Service SHALL mengekspos seluruh operasi jaringan sebagai `async`/`throws` API yang dipanggil dari ViewModel.
5. WHEN ExerciseDB_Service melakukan permintaan jaringan, THE ExerciseDB_Service SHALL membaca kredensial autentikasi API dari penyimpanan aman (`KeychainWrapper`) dan menyertakannya pada permintaan.
6. WHEN ExerciseDB_Service menerima respons sukses, THE ExerciseDB_Service SHALL menyimpan Exercise_Item yang di-decode ke dalam Exercise_Cache.
7. IF kredensial API tidak tersedia di `KeychainWrapper`, THEN THE ExerciseDB_Service SHALL mengembalikan error deskriptif tanpa melakukan permintaan jaringan.
8. IF permintaan jaringan gagal karena kesalahan transport, THEN THE ExerciseDB_Service SHALL mencoba ulang permintaan maksimal 3 kali sebelum mengembalikan error deskriptif.

---

### Requirement 5: Caching, Mode Offline, & Rate Limit ExerciseDB

**User Story:** As a user, I want exercise data to load quickly and remain available offline, so that I can use the library without a constant network connection or hitting API limits.

#### Acceptance Criteria

1. WHEN sebuah Exercise_Item telah disimpan di Exercise_Cache dan usianya sejak waktu penyimpanan terakhir tidak melebihi masa berlaku cache yang dikonfigurasi sebesar 7 hari (168 jam), THE ExerciseDB_Service SHALL mengembalikan data dari Exercise_Cache tanpa melakukan permintaan jaringan baru.
2. WHILE perangkat tidak memiliki koneksi jaringan, THE ExerciseDB_Service SHALL menyajikan Exercise_Item dan aset gambar/GIF yang tersedia dari Exercise_Cache, termasuk entri yang telah melampaui masa berlaku cache 7 hari (168 jam).
3. IF perangkat tidak memiliki koneksi jaringan dan data yang diminta tidak ada di Exercise_Cache, THEN THE layar peminta SHALL menampilkan Async_State `error` dengan pesan yang menjelaskan ketiadaan koneksi dan menyediakan kontrol "coba lagi" yang, ketika ditekan, memicu permintaan jaringan ulang untuk data yang sama.
4. IF perangkat tidak memiliki koneksi jaringan, data yang diminta tidak ada di Exercise_Cache, dan pengguna menekan kontrol "coba lagi" saat koneksi masih belum tersedia, THEN THE layar peminta SHALL tetap menampilkan Async_State `error` dengan pesan yang menjelaskan ketiadaan koneksi.
5. IF ExerciseDB_API menanggapi dengan status rate-limit (HTTP 429), THEN THE ExerciseDB_Service SHALL menghentikan pengiriman permintaan jaringan baru selama durasi yang ditunjukkan oleh respons jika tersedia, atau selama paling sedikit 60 detik jika tidak tersedia, mengembalikan data dari Exercise_Cache jika tersedia, dan mengembalikan error rate-limit deskriptif yang mengindikasikan batas permintaan terlampaui jika data tidak tersedia di Exercise_Cache.
6. WHEN sebuah entri Exercise_Cache yang usianya telah melampaui masa berlaku cache yang dikonfigurasi sebesar 7 hari (168 jam) diminta kembali dan koneksi jaringan tersedia, THE ExerciseDB_Service SHALL menghapus atau menyegarkan entri tersebut.
7. THE Exercise_Cache SHALL menyimpan metadata Exercise_Item menggunakan Core Data melalui `PersistenceController`.

---

### Requirement 6: Pemuatan & Caching Aset GIF/Gambar

**User Story:** As a user, I want exercise demo GIFs and images to load smoothly without stutter, so that browsing feels fast and polished.

#### Acceptance Criteria

1. WHEN sebuah view menampilkan GIF atau gambar demo dari sebuah Exercise_Item, THE PULSE_App SHALL memuat aset secara asinkron pada background thread tanpa memblokir main thread, dengan mempertahankan kecepatan render minimal 60 frame per detik selama pemuatan berlangsung.
2. WHEN sebuah aset GIF/gambar berhasil diunduh, THE PULSE_App SHALL menyimpan aset tersebut ke Exercise_Cache di disk dengan batas kapasitas maksimum 200 MB dan menyajikannya dari cache pada permintaan berikutnya tanpa mengunduh ulang.
3. WHEN ukuran Exercise_Cache mencapai batas kapasitas 200 MB, THE PULSE_App SHALL menghapus aset yang paling lama tidak diakses (least-recently-used) hingga total ukuran cache kembali berada di bawah batas tersebut.
4. WHILE sebuah aset GIF/gambar sedang dimuat dan belum selesai dalam 0,3 detik, THE PULSE_App SHALL menampilkan placeholder skeleton menggunakan `SkeletonLoader` hingga aset selesai dimuat.
5. IF pemuatan aset GIF/gambar gagal atau tidak selesai dalam 10 detik, THEN THE PULSE_App SHALL membatalkan permintaan, menampilkan placeholder fallback beserta simbol indikasi kesalahan, dan tetap berjalan tanpa crash.
6. IF pemuatan aset GIF/gambar gagal, THEN THE PULSE_App SHALL mencoba ulang pengunduhan maksimal 2 kali sebelum menampilkan placeholder fallback.
7. WHILE pengguna melakukan scroll pada daftar latihan, THE PULSE_App SHALL membatasi jumlah operasi dekode gambar serentak maksimal 4 operasi agar penggunaan memori tetap terbatas.

---

### Requirement 7: Atribusi ExerciseDB

**User Story:** As the app owner, I want to display required attribution for ExerciseDB, so that the app complies with the data source's licensing terms.

#### Acceptance Criteria

1. THE PULSE_App SHALL menampilkan atribusi sumber data ExerciseDB pada layar More, dan SHALL menjadikan atribusi tersebut dapat dicapai pengguna tanpa interaksi selain menggulir ke bagian atribusi pada layar tersebut.
2. WHERE atribusi ExerciseDB ditampilkan, THE PULSE_App SHALL menampilkan teks atribusi yang menyebutkan nama sumber "ExerciseDB" beserta sebuah tautan yang dapat diketuk menuju sumber ExerciseDB.
3. WHEN pengguna mengetuk tautan atribusi ExerciseDB, THE PULSE_App SHALL membuka URL sumber ExerciseDB.
4. IF tautan atribusi ExerciseDB tidak dapat dibuka, THEN THE PULSE_App SHALL menampilkan pesan error yang mengindikasikan kegagalan membuka tautan tanpa melakukan crash, dan SHALL tetap menampilkan teks atribusi.
5. THE PULSE_App SHALL mengekspos tautan atribusi ExerciseDB dengan accessibility label yang menyebutkan bahwa tautan tersebut membuka sumber ExerciseDB.

---

### Requirement 8: Exercise Library / Explorer

**User Story:** As a user, I want to browse thousands of exercises from ExerciseDB, so that I can discover exercises to add to my routines.

#### Acceptance Criteria

1. WHEN Library_Screen ditampilkan, THE Library_Screen SHALL meminta data latihan melalui sebuah ViewModel dengan batas waktu permintaan maksimum 10 detik (10.000 ms) dan menampilkan setiap Exercise_Item sebagai sebuah list row yang menampilkan minimal name (maksimum 80 karakter, dipotong dengan elipsis jika melebihi), target muscle, dan thumbnail demo.
2. WHILE thumbnail demo untuk sebuah Exercise_Item belum selesai dimuat, THE Library_Screen SHALL menampilkan placeholder thumbnail pada list row yang bersangkutan.
3. THE Library_Screen SHALL merender daftar latihan menggunakan `LazyVStack` atau `List` sehingga hanya baris yang terlihat yang dirender.
4. WHILE data sedang dimuat untuk pertama kali, THE Library_Screen SHALL menampilkan Async_State `loading` menggunakan placeholder skeleton dengan minimal 6 baris skeleton.
5. IF pengambilan data gagal atau batas waktu 10 detik terlampaui, THEN THE Library_Screen SHALL menampilkan Async_State `error` dengan pesan yang mendeskripsikan penyebab kegagalan dan sebuah kontrol untuk mencoba lagi, serta SHALL mempertahankan data yang sudah ditampilkan sebelumnya (jika ada) tanpa perubahan.
6. WHEN pengguna mengetuk kontrol coba lagi, THE Library_Screen SHALL mengulang permintaan data latihan melalui ViewModel dengan batas waktu permintaan maksimum 10 detik (10.000 ms).
7. WHEN hasil yang dapat ditampilkan kosong (0 Exercise_Item), THE Library_Screen SHALL menampilkan Async_State `empty` menggunakan `EmptyStateView`.
8. WHEN pengguna mengetuk sebuah list row, THE Library_Screen SHALL menavigasi ke Detail_Screen untuk Exercise_Item yang sesuai.
9. WHEN pengguna melakukan gesture refresh, THE Library_Screen SHALL meminta ulang data latihan melalui `refreshable` dengan batas waktu permintaan maksimum 10 detik (10.000 ms).

---

### Requirement 9: Pencarian & Pemfilteran

**User Story:** As a user, I want to search and filter exercises by muscle, equipment, and body part, so that I can quickly narrow down to relevant exercises.

#### Acceptance Criteria

1. WHEN pengguna memasukkan teks pencarian melalui `searchable` sepanjang minimal 1 karakter (setelah spasi di awal/akhir dihapus), THE Library_Screen SHALL menampilkan dalam waktu maksimal 500 milidetik hanya Exercise_Item yang nama-nya mengandung teks tersebut sebagai substring dengan pencocokan tanpa peka huruf besar/kecil.
2. THE Library_Screen SHALL menyediakan kontrol filter untuk target muscle, equipment, dan body part menggunakan filter chip dari Component_Library, di mana setiap kategori mengizinkan pemilihan satu atau lebih nilai secara bersamaan.
3. WHEN satu atau lebih filter aktif, THE Library_Screen SHALL menampilkan hanya Exercise_Item yang memenuhi seluruh kategori filter yang aktif, dengan logika AND antar kategori dan logika OR antar nilai dalam kategori yang sama.
4. WHEN pengguna menerapkan teks pencarian bersama satu atau lebih filter, THE Library_Screen SHALL menampilkan hanya Exercise_Item yang memenuhi kriteria teks pencarian sekaligus seluruh kategori filter aktif.
5. WHEN pengguna mengaktifkan kontrol hapus seluruh kriteria sehingga seluruh filter dan teks pencarian kosong, THE Library_Screen SHALL menampilkan kembali daftar latihan lengkap dalam waktu maksimal 500 milidetik.
6. WHEN kombinasi pencarian dan filter tidak menghasilkan Exercise_Item apa pun, THE Library_Screen SHALL menampilkan Async_State `empty` dengan pesan yang menyatakan tidak ada hasil dan menyarankan pengguna melonggarkan atau menghapus kriteria.
7. WHILE sesi aplikasi masih aktif, WHEN pengguna meninggalkan dan kembali ke Library_Screen melalui navigasi mundur, THE Library_Screen SHALL mempertahankan teks pencarian dan seluruh nilai filter aktif yang terakhir diterapkan beserta hasil yang sesuai.
8. WHEN pengguna mengaktifkan satu filter atau menghapus satu nilai filter, THE Library_Screen SHALL memperbarui daftar Exercise_Item yang ditampilkan dalam waktu maksimal 500 milidetik.

---

### Requirement 10: Enriched Exercise Detail

**User Story:** As a user, I want a detailed view of each exercise with a demo, muscles, equipment, and form tips, so that I understand how to perform it correctly.

#### Acceptance Criteria

1. WHEN Detail_Screen ditampilkan untuk sebuah Exercise_Item, THE Detail_Screen SHALL menampilkan demo GIF, name, target muscle, secondaryMuscles, equipment, dan seluruh langkah instructions dalam urutan persis seperti yang disediakan Exercise_Item.
2. WHILE demo GIF sedang dimuat, THE Detail_Screen SHALL menampilkan placeholder skeleton menggunakan `SkeletonLoader`.
3. IF sebuah field opsional (secondaryMuscles, equipment, atau instructions) pada Exercise_Item kosong atau tidak tersedia, THEN THE Detail_Screen SHALL menyembunyikan bagian terkait beserta judul bagiannya alih-alih menampilkan area kosong.
4. WHERE sebuah Exercise_Item berkaitan dengan latihan yang didukung Camera_Coaching, THE Detail_Screen SHALL menampilkan kontrol untuk membuka Camera_Coaching dengan latihan tersebut pra-terpilih melalui `App_Router.openCamera(with:)`.
5. IF sebuah Exercise_Item tidak memiliki latihan yang cocok dan didukung Camera_Coaching, THEN THE Detail_Screen SHALL menyembunyikan kontrol pembuka Camera_Coaching.
6. WHEN pengguna mengetuk kontrol "tambah ke rutinitas" dan sebuah Routine sedang dibangun pada Builder_Screen, THE Detail_Screen SHALL menambahkan sebuah Routine_Item yang mereferensikan Exercise_Item tersebut ke Routine dan menampilkan konfirmasi dalam waktu maksimal 1 detik.
7. IF pengguna mengetuk kontrol "tambah ke rutinitas" saat tidak ada Routine yang sedang dibangun, THEN THE Detail_Screen SHALL membuat Routine baru lalu menambahkan Routine_Item yang mereferensikan Exercise_Item tersebut.
8. WHEN pengguna mengetuk kontrol bertanya kepada AI_Coach, THE Detail_Screen SHALL membuka AI_Coach dengan konteks Exercise_Item yang sedang ditampilkan sudah disertakan dalam prompt awal.

---

### Requirement 11: Muscle Map / Body Heatmap

**User Story:** As a user, I want an interactive body muscle map, so that I can tap a body region and see exercises that target that muscle.

#### Acceptance Criteria

1. WHEN Muscle_Map_Screen ditampilkan, THE Muscle_Map_Screen SHALL menampilkan peta tubuh interaktif dengan Body_Region yang dapat dipilih, masing-masing memiliki area ketukan minimal 44x44 poin.
2. WHEN pengguna mengetuk sebuah Body_Region, THE Muscle_Map_Screen SHALL meminta dan menampilkan daftar Exercise_Item yang target muscle atau bodyPart-nya sesuai dengan Body_Region tersebut, dengan batas waktu permintaan maksimum 10 detik (10.000 ms).
3. WHEN pengguna mengetuk sebuah Exercise_Item dari hasil Body_Region, THE Muscle_Map_Screen SHALL menavigasi ke Detail_Screen untuk Exercise_Item tersebut.
4. WHILE daftar Exercise_Item untuk sebuah Body_Region sedang dimuat, THE Muscle_Map_Screen SHALL menampilkan Async_State `loading`.
5. IF tidak ada Exercise_Item yang sesuai untuk Body_Region yang dipilih, THEN THE Muscle_Map_Screen SHALL menampilkan Async_State `empty` dengan pesan yang menyatakan tidak ada latihan untuk area tersebut dan menyarankan pengguna memilih Body_Region lain.
6. IF pengambilan daftar Exercise_Item gagal atau batas waktu 10 detik terlampaui, THEN THE Muscle_Map_Screen SHALL menampilkan Async_State `error` dengan kontrol untuk mencoba lagi dan mempertahankan sorotan Body_Region yang dipilih.
7. WHEN pengguna mengetuk kontrol coba lagi, THE Muscle_Map_Screen SHALL meminta ulang daftar Exercise_Item untuk Body_Region yang sama dengan batas waktu maksimum 10 detik (10.000 ms).
8. WHEN sebuah Body_Region dipilih, THE Muscle_Map_Screen SHALL menyorot Body_Region tersebut menggunakan warna `themePrimary` dari Brand_Palette dan menghapus sorotan Body_Region yang sebelumnya dipilih.
9. THE Muscle_Map_Screen SHALL mengekspos setiap Body_Region yang dapat diketuk dengan accessibility label yang menyebutkan nama otot/bagian tubuh.

---

### Requirement 12: Workout Builder — Pembuatan Rutinitas

**User Story:** As a user, I want to create custom workout routines by adding exercises with sets, reps, and rest, so that I can follow a structured plan.

#### Acceptance Criteria

1. WHEN pengguna membuat Routine baru pada Builder_Screen, THE Builder_Screen SHALL memungkinkan pengguna memberikan nama Routine sepanjang 1 sampai 100 karakter dan menambahkan 1 sampai 50 Routine_Item.
2. WHEN pengguna menambahkan sebuah Exercise_Item ke Routine, THE Builder_Screen SHALL membuat sebuah Routine_Item yang mereferensikan id Exercise_Item beserta nilai sets, reps, dan rest (detik) yang dapat diedit pengguna.
3. THE Builder_Screen SHALL memvalidasi bahwa sets merupakan bilangan bulat dari 1 sampai 100, reps merupakan bilangan bulat dari 1 sampai 1000, dan rest merupakan bilangan bulat dari 0 sampai 3600 detik sebelum menyimpan Routine.
4. IF pengguna menyimpan Routine dan nilai sets, reps, atau rest pada salah satu Routine_Item berada di luar rentang yang ditentukan atau bukan bilangan bulat, THEN THE Builder_Screen SHALL mencegah penyimpanan, menampilkan pesan validasi yang mengidentifikasi field dan rentang nilai yang valid, dan mempertahankan masukan pengguna tanpa kehilangan data.
5. IF pengguna mencoba menyimpan Routine tanpa nama atau tanpa Routine_Item, THEN THE Builder_Screen SHALL mencegah penyimpanan dan menampilkan pesan validasi yang mengidentifikasi field yang belum terpenuhi.
6. WHEN pengguna mengubah urutan Routine_Item, THE Builder_Screen SHALL mempertahankan urutan baru tersebut pada Routine yang disimpan.
7. WHEN pengguna menghapus sebuah Routine_Item, THE Builder_Screen SHALL menghapus entri tersebut dari Routine tanpa mengubah nilai sets, reps, rest, maupun urutan relatif Routine_Item lainnya.

---

### Requirement 13: Workout Builder — Persistensi (Core Data)

**User Story:** As a user, I want my custom routines to be saved, so that they persist across app launches.

#### Acceptance Criteria

1. WHEN pengguna menyimpan sebuah Routine, THE PULSE_App SHALL mempertahankan Routine beserta seluruh Routine_Item terurutnya menggunakan Core Data melalui `PersistenceController` dalam waktu maksimal 2 detik.
2. THE PULSE_App SHALL menyimpan setiap Routine dengan id unik (`UUID`), name (1 sampai 100 karakter setelah dipangkas spasi di awal/akhir), tanggal pembuatan, dan relasi terurut ke Routine_Item-nya (0 sampai 100 Routine_Item).
3. THE PULSE_App SHALL menyimpan setiap Routine_Item dengan referensi id Exercise_Item, sets (1 sampai 99), reps (1 sampai 999), rest dalam detik (0 sampai 3600), dan posisi urutan (integer mulai dari 0, unik dan kontigu dalam satu Routine).
4. WHEN pengguna membuka kembali aplikasi, THE PULSE_App SHALL memuat seluruh Routine tersimpan beserta Routine_Item-nya, diurutkan berdasarkan posisi urutan secara menaik.
5. WHEN pengguna mengedit Routine tersimpan dan menyimpannya kembali, THE PULSE_App SHALL memperbarui record yang ada berdasarkan id `UUID` yang sama alih-alih membuat duplikat.
6. WHEN pengguna menghapus Routine, THE PULSE_App SHALL menghapus Routine beserta seluruh Routine_Item terkait melalui cascade delete sehingga tidak ada Routine_Item yatim yang tersisa.
7. IF operasi penyimpanan Core Data gagal, THEN THE PULSE_App SHALL menampilkan pesan error yang mengindikasikan kegagalan penyimpanan, mempertahankan state yang belum tersimpan tanpa kehilangan data, dan menyediakan opsi untuk mencoba menyimpan ulang.
8. IF pengguna mencoba menyimpan Routine dengan name kosong atau hanya berisi spasi, THEN THE PULSE_App SHALL menolak penyimpanan dan menampilkan pesan yang mengindikasikan name wajib diisi.
9. IF pengguna mencoba menyimpan Routine_Item dengan nilai sets, reps, atau rest di luar rentang yang ditetapkan, THEN THE PULSE_App SHALL menolak penyimpanan dan menampilkan pesan yang mengindikasikan nilai tidak valid beserta rentang yang diizinkan.

---

### Requirement 14: Scheduling (Jadwal)

**User Story:** As a user, I want to schedule my workout routines on a calendar, so that I can plan when to train.

#### Acceptance Criteria

1. WHEN Schedule_Screen ditampilkan, THE Schedule_Screen SHALL menampilkan tampilan kalender/jadwal yang menandai setiap tanggal yang memiliki minimal satu Scheduled_Workout.
2. WHEN pengguna menjadwalkan sebuah Routine pada tanggal tertentu, THE PULSE_App SHALL membuat sebuah Scheduled_Workout dengan id unik (`UUID`) yang menautkan id Routine ke tanggal/waktu tersebut dan mempertahankannya menggunakan Core Data melalui `PersistenceController` dalam waktu maksimal 2 detik.
3. WHEN pengguna memilih sebuah tanggal, THE Schedule_Screen SHALL menampilkan seluruh Scheduled_Workout untuk tanggal tersebut, diurutkan berdasarkan waktu secara menaik.
4. WHEN pengguna menghapus sebuah Scheduled_Workout, THE PULSE_App SHALL menghapus entri tersebut tanpa menghapus Routine yang direferensikan.
5. IF sebuah Scheduled_Workout mereferensikan Routine yang telah dihapus, THEN THE Schedule_Screen SHALL menampilkan entri tersebut dengan keadaan deskriptif yang menyatakan Routine tidak lagi tersedia dan menyediakan kontrol untuk menghapus entri menggantung tersebut tanpa melakukan crash.
6. WHEN tidak ada Scheduled_Workout pada tanggal yang dipilih, THE Schedule_Screen SHALL menampilkan Async_State `empty` dengan kontrol untuk menambahkan jadwal.
7. IF operasi penyimpanan Scheduled_Workout ke Core Data gagal, THEN THE PULSE_App SHALL menampilkan pesan error yang mengindikasikan kegagalan tanpa melakukan crash dan mempertahankan masukan pengguna agar dapat dicoba kembali.

---

### Requirement 15: Integrasi AI Coach (GLM)

**User Story:** As a user, I want to ask the existing AI coach about exercises and routines from within the new flows, so that I get contextual guidance without leaving my task.

#### Acceptance Criteria

1. WHERE sebuah Detail_Screen ditampilkan, THE PULSE_App SHALL menampilkan kontrol untuk membuka AI_Coach.
2. WHEN pengguna mengaktifkan kontrol AI_Coach dari Detail_Screen, THE PULSE_App SHALL membuka AI_Coach dengan prompt awal yang menyertakan minimal name dan deskripsi Exercise_Item yang sedang dilihat.
3. WHERE sebuah Routine ditampilkan pada Builder_Screen, THE PULSE_App SHALL menampilkan kontrol untuk membuka AI_Coach.
4. WHEN pengguna mengaktifkan kontrol AI_Coach dari Builder_Screen, THE PULSE_App SHALL membuka AI_Coach dengan prompt awal yang menyertakan minimal name Routine dan daftar Exercise_Item di dalamnya.
5. WHEN AI_Coach dibuka dengan konteks dari sebuah layar baru, THE PULSE_App SHALL menggunakan `GLMService` dan `ChatView` yang sudah ada tanpa menggandakan logika layanan chat.
6. IF `GLMService` mengembalikan error atau tidak menanggapi dalam 30 detik, THEN THE AI_Coach SHALL menampilkan pesan error deskriptif, menyembunyikan indikator loading, dan mempertahankan seluruh riwayat percakapan tanpa perubahan.
7. WHILE menunggu respons dari `GLMService`, THE AI_Coach SHALL menampilkan indikator loading yang muncul dalam waktu maksimal 500 milidetik sejak permintaan dikirim.

---

### Requirement 16: Redesign Visual Layar Kamera

**User Story:** As a user, I want the camera coaching screen to look polished and on-brand, so that real-time coaching feels premium and readable.

#### Acceptance Criteria

1. THE Camera_Coaching SHALL menampilkan elemen overlay (feedback banner, rep counter, kontrol) menggunakan semantic `Color` tokens, spacing tokens, dan corner radius tokens dari Design_System tanpa nilai warna, spacing, atau corner radius yang di-hardcode.
2. THE Camera_Coaching SHALL mempertahankan fungsi pose-analysis, rep-counting, dan form-feedback yang ada sehingga menghasilkan hasil deteksi yang identik untuk masukan kamera yang sama seperti sebelum redesign.
3. WHILE Camera_Coaching aktif, THE Camera_Coaching SHALL menampilkan feedback banner dengan rasio kontras teks minimal 4.5:1 terhadap latar banner dan opasitas latar banner minimal 80% sehingga teks tetap terbaca di atas umpan kamera yang bervariasi.
4. THE Camera_Coaching SHALL menampilkan kontrol tutup/keluar dan reset menggunakan komponen dari Component_Library dengan accessibility label non-kosong dan area ketukan minimal 44x44 poin.
5. WHEN Camera_Coaching dibuka dengan latihan pra-terpilih melalui `App_Router.openCamera(with:)`, THE Camera_Coaching SHALL memulai pelacakan latihan tersebut tanpa memerlukan langkah pemilihan tambahan dalam waktu maksimal 2 detik.
6. IF Camera_Coaching dibuka melalui `App_Router.openCamera(with:)` tanpa latihan atau dengan latihan yang tidak didukung, THEN THE Camera_Coaching SHALL menampilkan keadaan pemilihan latihan default tanpa melakukan crash.
7. IF izin akses kamera ditolak, THEN THE Camera_Coaching SHALL menampilkan pesan yang menjelaskan kebutuhan izin kamera beserta kontrol menuju pengaturan sistem tanpa melakukan crash.

---

### Requirement 17: Aksesibilitas

**User Story:** As a user who relies on assistive technologies, I want every interactive element to be labeled, so that I can navigate the app with VoiceOver.

#### Acceptance Criteria

1. THE PULSE_App SHALL menyediakan accessibility label non-kosong dan accessibility identifier yang unik dalam cakupan satu layar untuk setiap elemen interaktif pada layar baru (Library_Screen, Detail_Screen, Builder_Screen, Muscle_Map_Screen, Schedule_Screen) dan layar kamera yang diredesign.
2. WHERE sebuah elemen menyampaikan informasi melalui warna saja (misalnya highlight Body_Region), THE PULSE_App SHALL menyediakan label teks atau accessibility value setara yang menyampaikan informasi yang sama tanpa bergantung pada warna.
3. THE PULSE_App SHALL mendukung Dynamic Type pada teks layar baru untuk seluruh kategori ukuran sistem dari ukuran terkecil hingga kategori aksesibilitas terbesar (accessibility XXXL/AX5), sehingga seluruh teks dan kontrol interaktif tetap terlihat penuh tanpa terpotong dan tanpa tertutup elemen lain.
4. WHEN Async_State sebuah layar baru bertransisi ke `loading`, `error`, atau `empty` dan VoiceOver aktif, THE PULSE_App SHALL mengumumkan perubahan status tersebut melalui VoiceOver dalam waktu maksimal 1 detik (1.000 ms) setelah transisi.
5. THE PULSE_App SHALL memastikan setiap target ketukan pada layar baru memiliki area ketukan dengan ukuran minimal 44x44 poin.
6. IF sebuah elemen interaktif pada layar baru tidak memiliki accessibility label non-kosong saat dirender, THEN THE PULSE_App SHALL menggunakan accessibility label fallback deskriptif yang menyebutkan fungsi elemen tersebut alih-alih membiarkan label kosong.

---

### Requirement 18: Performa

**User Story:** As a user, I want lists and images to scroll smoothly, so that the app feels responsive even with thousands of exercises.

#### Acceptance Criteria

1. THE PULSE_App SHALL merender daftar dengan lebih dari 20 item menggunakan `LazyVStack` atau `LazyHStack`.
2. THE PULSE_App SHALL NOT melakukan pemanggilan jaringan sinkron maupun operasi yang memblokir main thread lebih dari 16 milidetik di dalam `body` sebuah view.
3. WHILE pengguna melakukan scroll pada Library_Screen yang berisi 1.000 item atau lebih, THE PULSE_App SHALL mempertahankan frame rate minimal 55 frame per detik (waktu render per frame maksimal 16,67 milidetik).
4. WHEN pengguna melakukan scroll pada Library_Screen, THE PULSE_App SHALL menyajikan thumbnail dari Exercise_Cache untuk item yang sudah pernah dimuat dalam waktu maksimal 100 milidetik tanpa mengunduh ulang.
5. WHEN dekode gambar/GIF atau permintaan jaringan dijalankan, THE PULSE_App SHALL menjalankan operasi tersebut di luar main thread.
6. WHEN hasil dekode gambar/GIF atau permintaan jaringan telah tersedia, THE PULSE_App SHALL memperbarui `@Published` properties di main thread.
7. WHILE memuat daftar dengan lebih dari 50 item dari ExerciseDB_Service, THE PULSE_App SHALL memuat data secara bertahap dalam batch maksimal 50 item per permintaan alih-alih memuat seluruh dataset sekaligus.
8. IF permintaan pemuatan bertahap data dari ExerciseDB_Service gagal, THEN THE PULSE_App SHALL mempertahankan item yang sudah berhasil dimuat dan menampilkan indikator kesalahan yang menyatakan kegagalan pemuatan beserta opsi untuk mencoba kembali.

---

### Requirement 19: Konsistensi Status Asinkron Lintas Layar

**User Story:** As a user, I want consistent loading, empty, and error states across every new screen, so that the app behaves predictably.

#### Acceptance Criteria

1. THE PULSE_App SHALL merepresentasikan status setiap layar berbasis data sebagai Async_State tunggal yang dikelola oleh ViewModel layar tersebut, dengan nilai yang dibatasi tepat pada salah satu dari `loading`, `loaded`, `empty`, atau `error`.
2. WHILE sebuah layar berada pada Async_State `loading`, THE PULSE_App SHALL menampilkan placeholder skeleton atau `ProgressView` dalam waktu maksimum 100 milidetik sejak layar memasuki state `loading`, dan SHALL tidak menampilkan konten kosong maupun pesan error.
3. WHEN sebuah layar memasuki Async_State `empty` (jumlah item data sama dengan 0), THE PULSE_App SHALL menampilkan `EmptyStateView` yang memuat pesan teks yang menjelaskan ketiadaan data.
4. WHERE sebuah layar pada Async_State `empty` memiliki tindakan utama yang dapat dilakukan pengguna untuk menambah atau memuat data, THE PULSE_App SHALL menampilkan kontrol tindakan tersebut di dalam `EmptyStateView`.
5. WHEN sebuah layar memasuki Async_State `error`, THE PULSE_App SHALL menampilkan pesan error deskriptif yang mengindikasikan penyebab kegagalan beserta sebuah kontrol "coba lagi", serta SHALL mempertahankan data yang telah dimuat sebelumnya tanpa mengubahnya.
6. WHEN pengguna mengaktifkan kontrol "coba lagi" pada Async_State `error`, THE PULSE_App SHALL mengembalikan layar ke Async_State `loading` dan memulai ulang operasi pemuatan data.
7. THE PULSE_App SHALL memastikan setiap layar berada tepat pada satu Async_State pada satu waktu dan melakukan transisi hanya ke satu Async_State berikutnya pada setiap perubahan status.
