# Implementation Plan: App Redesign & ExerciseDB Hub

## Overview

Rencana implementasi ini memecah desain menjadi langkah-langkah coding inkremental untuk iOS 16.4 / Swift 5.7 / SwiftUI (Core Data, bukan SwiftData; tanpa `AnyView`; tanpa hex hardcoded; satu ViewModel per layar).

Urutan kerja: **fondasi** (Design System / Component Library, `AsyncState`, Core Data, ExerciseDBService + caching, AssetLoader) → **layar** (Library, Detail, Muscle Map, Builder, Schedule, integrasi AI Coach) → **cross-cutting polish** (redesign overlay kamera, atribusi, aksesibilitas, performa). Setiap langkah dibangun di atas langkah sebelumnya dan diakhiri dengan wiring sehingga tidak ada kode menggantung.

Konvensi pengujian:
- **Property-Based Testing** memakai **SwiftCheck**, minimal **100 iterasi** per properti, satu test per properti.
- Setiap test PBT diberi komentar tag: `// Feature: app-redesign-exercise-hub, Property {n}: {teks properti}`.
- Properti Core Data dijalankan terhadap in-memory `PersistenceController.preview`; properti jaringan memakai mock `URLProtocol` + mock Keychain/Reachability.
- Sub-task pengujian ditandai `*` (opsional, dapat dilewati untuk MVP cepat).

## Tasks

- [x] 1. Fondasi Design System: Motion & AsyncState
  - [x] 1.1 Implementasi konstanta `Motion`
    - Buat `Core/DesignSystem/Motion.swift` dengan `screenTransition` (0.30s), `chipToggle` (0.20s), `emphasis` (spring) — seluruh durasi dalam rentang 200–400ms, mengacu token, tanpa nilai hardcoded di view
    - _Requirements: 1.7_
  - [x] 1.2 Write property test untuk konstanta Motion
    - **Property 47: Motion transisi dalam rentang 200–400ms**
    - **Validates: Requirements 1.7**
  - [x] 1.3 Implementasi tipe generik `AsyncState<Value: Equatable>`
    - Buat `Core/DesignSystem/AsyncState.swift` dengan kasus `loading/loaded/empty/error(message:)`, `Equatable`
    - _Requirements: 19.1, 19.7_
  - [x] 1.4 Write property test untuk eksklusivitas AsyncState
    - **Property 45: Eksklusivitas Async_State**
    - **Validates: Requirements 19.1, 19.7**

- [x] 2. Component Library di atas Design tokens
  - [x] 2.1 Implementasi komponen statis: `PulseCard`, `PulseBadge`, `SectionHeader`
    - Buat file terpisah di `Core/DesignSystem/`; pakai semantic `Color`, `.spacing*`, `.cornerRadius*`; komposisi via `@ViewBuilder` tanpa `AnyView`
    - _Requirements: 2.1, 2.2, 2.3, 2.5_
  - [x] 2.2 Implementasi `PrimaryButton` & `SecondaryButton`
    - Label & identifier accessibility wajib (non-opsional); area ketukan ≥44×44; state disabled `allowsHitTesting(false)` + visual berbeda + tidak memicu `action`
    - _Requirements: 2.1, 2.2, 2.4, 2.6_
  - [x] 2.3 Implementasi `FilterChip`
    - Toggle visual terpilih/tidak; `accessibilityValue` "selected"/"not selected"; min 44×44; style kondisional via modifier `@ViewBuilder`/`AnyShapeStyle` (bukan `AnyView`)
    - _Requirements: 2.4, 2.7_
  - [x] 2.4 Implementasi `ExerciseListRow`
    - Thumbnail + name + target muscle; helper pemotongan nama ≤80 char dengan elipsis sebagai prefiks nama asli
    - _Requirements: 2.1, 2.2, 8.1_
  - [x] 2.5 Implementasi `AsyncStateView` + `ErrorStateView`
    - Wrapper `@ViewBuilder` yang merender tepat satu cabang; `loading` → skeleton/progress (≤100ms); `empty` → `EmptyStateView` (reuse); `error` → pesan + retry yang mengembalikan state ke `loading`
    - _Requirements: 19.2, 19.3, 19.4, 19.5, 19.6_
  - [x] 2.6 Write property test untuk FilterChip accessibility value
    - **Property 42: Filter chip mencerminkan state pada accessibility value**
    - **Validates: Requirements 2.7**
  - [x] 2.7 Write property test untuk tombol disabled
    - **Property 43: Tombol disabled tidak memicu aksi**
    - **Validates: Requirements 2.6**
  - [x] 2.8 Write property test untuk area ketukan komponen
    - **Property 41: Area ketukan ≥ 44×44 poin**
    - **Validates: Requirements 2.4, 11.1, 17.5**
  - [x] 2.9 Write property test untuk kontras token teks/latar
    - **Property 38: Kontras teks ≥ ambang WCAG (termasuk banner kamera)**
    - **Validates: Requirements 1.3, 16.3**
  - [x] 2.10 Write property test untuk rendering AsyncStateView & retry
    - **Property 46: Rendering Async_State sesuai state & retry kembali ke loading**
    - **Validates: Requirements 19.2, 19.6**

- [x] 3. Checkpoint — fondasi Design System
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Core Data: entity baru & validasi
  - [x] 4.1 Tambah entity ke `FitnessApp.xcdatamodeld` + file `*+CoreData.swift`
    - Tambah `CachedExercise`, `Routine`, `RoutineItem`, `ScheduledWorkout` mengikuti pola `WorkoutLog+CoreData.swift`; relasi `Routine.items` ordered + Delete Rule Cascade; `RoutineItem.routine` Nullify; `ScheduledWorkout.routineID` sebagai `UUID` (referensi lemah)
    - _Requirements: 5.7, 13.2, 13.3, 13.6, 14.2_
  - [x] 4.2 Implementasi `RoutineValidator` + value types (`RoutineDraft`, `RoutineItemDraft`, `RoutineSnapshot`, `RoutineItemSnapshot`)
    - Konstanta tunggal: sets 1…99, reps 1…999, rest 0…3600, nameLength 1…100, itemCount 1…50; `validate` mengembalikan error yang mengidentifikasi field & indeks tanpa mengubah input
    - _Requirements: 12.1, 12.3, 12.4, 12.5, 13.8, 13.9_
  - [x] 4.3 Write property test untuk RoutineValidator
    - **Property 29: Validasi Routine benar terhadap rentang & kelengkapan**
    - **Validates: Requirements 12.1, 12.3, 12.4, 12.5, 13.8, 13.9**

- [x] 5. Repositories Core Data
  - [x] 5.1 Implementasi `ExerciseMetadataCache`
    - `upsert([ExerciseItem])`, `load(id:)`, `loadAll`, `loadByBodyPart`, `loadByTarget`, `evictExpired(now:)`; array di-serialize JSON; `cachedAt` untuk TTL; baca via `viewContext`, tulis via background context
    - _Requirements: 5.7, 4.6_
  - [x] 5.2 Write property test untuk cache insert/contains
    - **Property 3: Sukses fetch menyimpan & dapat dibaca ulang (insert/contains)**
    - **Validates: Requirements 4.6**
  - [x] 5.3 Implementasi `RoutineRepository`
    - `save(_ draft:) -> UUID` (create/update by UUID), `loadAll` (urut `orderPosition` asc), `delete(id:)` (cascade); normalisasi `orderPosition` menjadi kontigu 0..n−1 saat simpan & hapus item
    - _Requirements: 13.1, 13.2, 13.4, 13.5, 13.6, 12.6, 12.7_
  - [x] 5.4 Write property test untuk urutan & posisi kontigu
    - **Property 30: Save/load mempertahankan urutan & posisi kontigu 0..n-1**
    - **Validates: Requirements 12.6, 13.2, 13.3, 13.4**
  - [x] 5.5 Write property test untuk hapus satu item
    - **Property 31: Hapus satu item mempertahankan item lain & menormalkan posisi**
    - **Validates: Requirements 12.7**
  - [x] 5.6 Write property test untuk simpan ulang UUID sama
    - **Property 32: Simpan ulang dengan UUID sama tidak menduplikasi**
    - **Validates: Requirements 13.5**
  - [x] 5.7 Write property test untuk cascade delete
    - **Property 33: Cascade delete tidak menyisakan Routine_Item yatim**
    - **Validates: Requirements 13.6**
  - [x] 5.8 Implementasi `ScheduleRepository`
    - `schedule(routineID:on:) -> UUID`, `workouts(on:)` (urut waktu asc), `datesWithWorkouts(in:)`, `delete(id:)` (pertahankan Routine), `resolve(_:) -> RoutineSnapshot?` (nil = dangling)
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_
  - [x] 5.9 Write property test untuk penanda kalender & pengurutan
    - **Property 34: Penanda kalender & pengurutan jadwal**
    - **Validates: Requirements 14.1, 14.3**
  - [x] 5.10 Write property test untuk hapus jadwal mempertahankan Routine
    - **Property 35: Hapus jadwal mempertahankan Routine**
    - **Validates: Requirements 14.4**
  - [x] 5.11 Write property test untuk referensi menggantung
    - **Property 36: Referensi menggantung terdeteksi & aman dihapus**
    - **Validates: Requirements 14.5**

- [x] 6. Networking: model & error ExerciseDB
  - [x] 6.1 Implementasi struct `ExerciseItem` (Codable)
    - Buat `Core/Networking/`-adjacent model dengan field id, name, gifUrl, target, secondaryMuscles, bodyPart, equipment, instructions; `Equatable`, `Identifiable`, `Hashable`
    - _Requirements: 4.1, 4.2_
  - [x] 6.2 Write property test untuk round-trip ExerciseItem
    - **Property 1: Exercise_Item Codable round-trip**
    - **Validates: Requirements 4.1, 4.2**
  - [x] 6.3 Implementasi `ExerciseDBEndpoint` + `ExerciseDBError`
    - Builder URL/host/path + query pagination; enum error `missingCredentials/offlineNoCache/rateLimited/network/decoding/timeout` `LocalizedError, Equatable`
    - _Requirements: 4.3, 4.7, 5.3, 5.5_

- [x] 7. ExerciseDBService
  - [x] 7.1 Implementasi `actor ExerciseDBService`
    - Cache-first (TTL 168 jam); baca kredensial via `KeychainWrapper`; offline serve cache (termasuk kedaluwarsa) atau `offlineNoCache`; gate HTTP 429 `rateLimitedUntil` dari `Retry-After`/default 60s; retry transport ≤3; decode aman tanpa tulis cache parsial; refresh entri kedaluwarsa saat online; clamp `limit` ≤50; seluruh API `async/throws` off-main-thread
    - _Requirements: 4.1, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 18.7_
  - [x] 7.2 Write property test untuk decode gagal
    - **Property 2: Decode gagal tidak menulis cache parsial**
    - **Validates: Requirements 4.3**
  - [x] 7.3 Write property test untuk tanpa kredensial
    - **Property 4: Tanpa kredensial → error tanpa request jaringan**
    - **Validates: Requirements 4.5, 4.7**
  - [x] 7.4 Write property test untuk batas retry transport
    - **Property 5: Kesalahan transport dibatasi maksimal 3 percobaan**
    - **Validates: Requirements 4.8**
  - [x] 7.5 Write property test untuk cache segar tanpa jaringan
    - **Property 6: Cache segar (≤7 hari) disajikan tanpa jaringan**
    - **Validates: Requirements 5.1**
  - [x] 7.6 Write property test untuk offline menyajikan seluruh cache
    - **Property 7: Offline menyajikan seluruh cache termasuk yang kedaluwarsa**
    - **Validates: Requirements 5.2**
  - [x] 7.7 Write property test untuk offline tanpa cache idempoten
    - **Property 8: Offline tanpa cache → error idempоten pada retry**
    - **Validates: Requirements 5.3, 5.4**
  - [x] 7.8 Write property test untuk HTTP 429 menahan request
    - **Property 9: HTTP 429 menahan permintaan baru selama window**
    - **Validates: Requirements 5.5**
  - [x] 7.9 Write property test untuk refresh entri kedaluwarsa
    - **Property 10: Entri kedaluwarsa + online disegarkan**
    - **Validates: Requirements 5.6**
  - [x] 7.10 Write property test untuk batas batch ≤50
    - **Property 44: Batch pemuatan inkremental dibatasi ≤50**
    - **Validates: Requirements 18.7**

- [x] 8. Asset caching & loading
  - [x] 8.1 Implementasi `actor AssetDiskCache` (LRU 200MB)
    - Simpan di `Caches/exercise-assets/`; index `lastAccessed`/`sizeBytes`; `data(for:)` update akses; `store` + `evictLRUIfNeeded` hingga < 200MB
    - _Requirements: 6.2, 6.3_
  - [x] 8.2 Write property test untuk round-trip & tanpa unduh ulang
    - **Property 11: Aset disk-cache round-trip & tanpa unduh ulang**
    - **Validates: Requirements 6.2**
  - [x] 8.3 Write property test untuk LRU eviction
    - **Property 12: LRU eviction menjaga kapasitas ≤200MB**
    - **Validates: Requirements 6.3**
  - [x] 8.4 Implementasi `AssetLoader` + `ExerciseAsyncImage`
    - Background load + simpan ke `AssetDiskCache`; skeleton via `SkeletonLoader` jika >0.3s; timeout 10s → fallback symbol tanpa crash; retry ≤2; batas dekode serentak ≤4 via semaphore/actor counter; sajikan dari cache ≤100ms; update `@Published` di main thread
    - _Requirements: 6.1, 6.4, 6.5, 6.6, 6.7, 18.4, 18.5, 18.6_
  - [x] 8.5 Write property test untuk batas retry pemuatan aset
    - **Property 13: Pemuatan aset gagal dibatasi maksimal 2 retry**
    - **Validates: Requirements 6.6**
  - [x] 8.6 Write property test untuk batas konkurensi dekode
    - **Property 14: Batas konkurensi dekode ≤4**
    - **Validates: Requirements 6.7**

- [x] 9. Checkpoint — service & caching
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Filter engine
  - [x] 10.1 Implementasi `FilterCriteria` + `ExerciseFilterEngine`
    - Pure function: substring case-insensitive untuk teks; AND antar kategori, OR antar nilai dalam kategori; kriteria kosong → daftar penuh tanpa perubahan
    - _Requirements: 9.1, 9.3, 9.4, 9.5, 9.8_
  - [x] 10.2 Write property test untuk filter engine
    - **Property 15: Pencarian, AND antar-kategori & OR antar-nilai, plus identitas kosong**
    - **Validates: Requirements 9.1, 9.3, 9.4, 9.5, 9.8**

- [x] 11. Navigasi & Router
  - [x] 11.1 Perluas `AppRouter` dengan `AppRoute` & deep link
    - Tambah `enum AppRoute`, `@Published var path`, `navigate(to:)`, `popToLibrary()`; perluas `handleDeepLink` untuk rute baru; rute/tab tidak valid → no-op tanpa crash; pertahankan field & `AppTab` yang ada
    - _Requirements: 3.2, 3.4, 3.6, 3.8_
  - [x] 11.2 Write property test untuk deep link tidak valid
    - **Property 17: Deep link tidak valid bersifat no-op**
    - **Validates: Requirements 3.6**
  - [x] 11.3 Write property test untuk deep link valid
    - **Property 18: Deep link valid menavigasi ke target**
    - **Validates: Requirements 3.8**

- [x] 12. Integrasi konteks AI Coach (reuse GLMService/ChatView)
  - [x] 12.1 Implementasi `ExerciseContextSeeder`
    - `prompt(for: ExerciseItem)` memuat name + target/equipment/instruksi; `prompt(for: RoutineSnapshot)` memuat name Routine + daftar nama Exercise_Item
    - _Requirements: 10.8, 15.2, 15.4_
  - [x] 12.2 Write property test untuk prompt konteks Exercise_Item
    - **Property 25: Prompt AI Coach memuat konteks Exercise_Item**
    - **Validates: Requirements 10.8, 15.2**
  - [x] 12.3 Write property test untuk prompt konteks Routine
    - **Property 26: Prompt AI Coach memuat konteks Routine**
    - **Validates: Requirements 15.4**
  - [x] 12.4 Tambah parameter `ChatSeed` ke `ChatViewModel` & `ChatView`
    - Parameter seed opsional (backward-compatible) yang mem-prefill `inputText` saat `messages` kosong; tetap memakai `DeepSeekService`/`ContextBuilder` yang ada tanpa duplikasi
    - _Requirements: 15.5, 15.6, 15.7_

- [x] 13. Library_Screen
  - [x] 13.1 Implementasi `LibraryViewModel`
    - `@MainActor`, `@Published private(set) var state: AsyncState`; pagination batch ≤50; timeout 10s; debounce pencarian/filter ≤500ms; retry mempertahankan data lama; pertahankan `searchText`/`activeFilters` selama sesi (state restoration); pakai `ExerciseDBService` + `ExerciseFilterEngine`
    - _Requirements: 8.1, 8.5, 8.6, 8.9, 9.1, 9.5, 9.7, 9.8, 18.7, 18.8, 19.5_
  - [x] 13.2 Write property test untuk error mempertahankan data
    - **Property 20: State error mempertahankan data yang sudah dimuat**
    - **Validates: Requirements 8.5, 18.8, 19.5**
  - [x] 13.3 Write property test untuk preservasi pencarian & filter
    - **Property 16: Library mempertahankan teks pencarian & filter saat kembali**
    - **Validates: Requirements 3.5, 9.7**
  - [x] 13.4 Implementasi `LibraryView`
    - `List`/`LazyVStack` baris `ExerciseListRow`; `.searchable`, `.refreshable`, filter chips; `AsyncStateView` untuk loading (skeleton ≥6 baris)/empty/error; tap row → `router.navigate(.exerciseDetail)`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.7, 8.8, 9.2, 9.6, 18.1, 3.3_
  - [x] 13.5 Write property test untuk pemotongan nama list row
    - **Property 19: Pemotongan nama list row ≤80 karakter**
    - **Validates: Requirements 8.1**

- [x] 14. Detail_Screen
  - [x] 14.1 Implementasi `CameraExerciseMapper`
    - `map(_ item:) -> ExerciseType?` berdasarkan name/target; nil jika tidak didukung kamera
    - _Requirements: 10.4, 10.5_
  - [x] 14.2 Write property test untuk visibilitas kontrol kamera
    - **Property 23: Kontrol kamera tampil jika dan hanya jika ter-map ke ExerciseType**
    - **Validates: Requirements 10.4, 10.5**
  - [x] 14.3 Implementasi `ExerciseDetailViewModel`
    - Aksi "tambah ke rutinitas" (buat Routine baru bila belum ada, tambah tepat satu `RoutineItem`) via `RoutineRepository`; buka kamera via `router.openCamera`; buka AI Coach via `ChatSeed` + `ExerciseContextSeeder`
    - _Requirements: 10.4, 10.6, 10.7, 10.8, 15.1, 15.2_
  - [x] 14.4 Write property test untuk tambah ke rutinitas
    - **Property 24: Tambah ke rutinitas menambah tepat satu item yang mereferensikan exercise**
    - **Validates: Requirements 10.6, 10.7**
  - [x] 14.5 Implementasi `ExerciseDetailView`
    - Demo GIF (skeleton saat loading), name, target, secondaryMuscles, equipment, instructions berurutan; sembunyikan section + judul untuk field opsional kosong; kontrol kamera hanya bila mappable; kontrol "tambah ke rutinitas" & "Tanya AI Coach"
    - _Requirements: 10.1, 10.2, 10.3, 10.5, 15.1_
  - [x] 14.6 Write property test untuk urutan instructions
    - **Property 21: Detail merender instructions sesuai urutan asli**
    - **Validates: Requirements 10.1**
  - [x] 14.7 Write property test untuk visibilitas section opsional
    - **Property 22: Section opsional tampil jika dan hanya jika field berisi**
    - **Validates: Requirements 10.3**

- [x] 15. Muscle_Map_Screen
  - [x] 15.1 Implementasi `MuscleMapViewModel`
    - Fetch by target/bodyPart per `Body_Region` dengan timeout 10s; `AsyncState` loading/empty/error + retry; pertahankan sorotan saat error; tepat satu region tersorot pada satu waktu
    - _Requirements: 11.2, 11.4, 11.5, 11.6, 11.7, 11.8_
  - [x] 15.2 Write property test untuk hasil cocok dengan region
    - **Property 27: Hasil Body_Region cocok dengan region**
    - **Validates: Requirements 11.2**
  - [x] 15.3 Write property test untuk satu region tersorot
    - **Property 28: Tepat satu Body_Region tersorot**
    - **Validates: Requirements 11.8**
  - [x] 15.4 Implementasi `MuscleMapView`
    - Body map dengan `Body_Region` tappable (area ≥44×44, accessibility label nama otot); highlight `themePrimary`; label/value teks setara untuk info-by-color; tap hasil → Detail
    - _Requirements: 11.1, 11.3, 11.8, 11.9, 17.2_

- [x] 16. Workout Builder_Screen
  - [x] 16.1 Implementasi `WorkoutBuilderViewModel`
    - Buat/edit Routine; tambah `RoutineItem` (sets/reps/rest editable); reorder & delete; validasi via `RoutineValidator` sebelum simpan; simpan via `RoutineRepository` ≤2s; error simpan → pesan + pertahankan input + retry; buka AI Coach dengan konteks Routine
    - _Requirements: 12.1, 12.2, 12.5, 12.6, 12.7, 13.1, 13.7, 15.3, 15.4_
  - [x] 16.2 Implementasi `WorkoutBuilderView`
    - Field nama; daftar editable `RoutineItem` dengan `.onMove`/delete; pesan validasi mengidentifikasi field & rentang; kontrol "Tanya AI Coach"
    - _Requirements: 12.2, 12.3, 12.4, 12.5, 13.8, 13.9, 15.3_

- [x] 17. Schedule_Screen
  - [x] 17.1 Implementasi `ScheduleViewModel`
    - Penanda kalender via `datesWithWorkouts`; jadwalkan Routine (`ScheduledWorkout` UUID) ≤2s; daftar per tanggal urut waktu; hapus jadwal (pertahankan Routine); tangani dangling via `resolve` → entri "Routine tidak lagi tersedia" + hapus aman; error simpan → pesan + pertahankan input
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.7_
  - [x] 17.2 Implementasi `ScheduleView`
    - Kalender menandai tanggal; pilih tanggal → daftar Scheduled_Workout; `AsyncState` empty + CTA tambah jadwal; kontrol hapus entri menggantung
    - _Requirements: 14.1, 14.3, 14.5, 14.6_

- [x] 18. Checkpoint — seluruh layar baru
  - Ensure all tests pass, ask the user if questions arise.

- [x] 19. Redesign visual overlay Camera_Coaching
  - [x] 19.1 Redesign overlay `CameraFeedView` memakai Component_Library & token
    - Feedback banner (opasitas ≥80%, kontras ≥4.5:1), rep counter, kontrol close/reset dari Component_Library (label non-kosong, ≥44×44); **pipeline deteksi `CameraViewModel`/`ExerciseDetector`/`SquatRepCounter`/`FlexFitClassifierManager` TIDAK diubah**; resolusi preselect `pendingExercise` (didukung/tidak/nil) aman tanpa crash; izin ditolak → pesan + tombol Settings
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_
  - [x] 19.2 Write property test untuk invarian deteksi kamera
    - **Property 37: Deteksi kamera invariant terhadap redesign**
    - **Validates: Requirements 16.2**
  - [x] 19.3 Write property test untuk resolusi preselect kamera
    - **Property 39: Resolusi preselect kamera aman untuk semua input**
    - **Validates: Requirements 16.5, 16.6**

- [x] 20. Atribusi ExerciseDB pada More
  - [x] 20.1 Tambah section atribusi ExerciseDB ke layar More
    - Teks menyebut "ExerciseDB" + tautan tappable membuka URL; kegagalan buka → pesan tanpa crash + teks tetap; accessibility label menyebut tautan membuka sumber ExerciseDB
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  - [x] 20.2 Write unit test untuk atribusi
    - Section ada, link membuka URL, kegagalan link menampilkan pesan & mempertahankan teks, a11y label benar
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 21. Aksesibilitas cross-cutting
  - [x] 21.1 Implementasi resolusi accessibility label dengan fallback & terapkan di layar baru
    - Helper yang menjamin label non-kosong (fallback deskriptif), identifier unik per layar; terapkan pada Library/Detail/Builder/MuscleMap/Schedule + overlay kamera
    - _Requirements: 17.1, 17.6_
  - [x] 21.2 Write property test untuk label aksesibilitas non-kosong
    - **Property 40: Label aksesibilitas selalu non-kosong (dengan fallback)**
    - **Validates: Requirements 17.1, 17.6**
  - [x] 21.3 Dukungan Dynamic Type & pengumuman VoiceOver perubahan AsyncState
    - Pastikan teks/kontrol layar baru tidak terpotong pada AX5; umumkan transisi `loading/error/empty` via `AccessibilityNotification.Announcement` ≤1 detik
    - _Requirements: 17.3, 17.4_

- [x] 22. Wiring & polish performa
  - [x] 22.1 Wire entry points & verifikasi performa daftar
    - Daftarkan rute Library/Builder/MuscleMap/Schedule dari Workout/More tab via `AppRoute` + `navigationDestination(for:)`; pastikan daftar >20 item memakai Lazy; tidak ada blok sinkron >16ms di `body`; thumbnail dari cache ≤100ms
    - _Requirements: 3.1, 3.2, 3.3, 3.7, 18.1, 18.2, 18.3, 18.4_

- [x] 23. Checkpoint akhir — pastikan semua test lulus
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Sub-task bertanda `*` bersifat opsional dan dapat dilewati untuk MVP cepat.
- Setiap task mereferensikan klausa requirement spesifik untuk traceability.
- Property test memvalidasi properti universal (SwiftCheck, ≥100 iterasi, satu test per properti, dengan tag `// Feature: app-redesign-exercise-hub, Property {n}`); unit/integration test memvalidasi contoh & edge case.
- Pipeline deteksi kamera dipertahankan apa adanya; hanya overlay yang diredesain (Property 37 menjaga invarian).
- Brand_Palette & token tidak diubah; seluruh styling mengacu `Color+Theme.swift`.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3", "4.1", "6.1"] },
    { "id": 1, "tasks": ["1.2", "1.4", "2.1", "2.2", "2.3", "2.4", "4.2", "6.2", "6.3", "8.1"] },
    { "id": 2, "tasks": ["2.5", "2.6", "2.7", "2.8", "2.9", "4.3", "5.1", "5.3", "5.8", "7.1", "8.2", "8.3", "8.4", "10.1", "11.1"] },
    { "id": 3, "tasks": ["2.10", "5.2", "5.4", "5.5", "5.6", "5.7", "5.9", "5.10", "5.11", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "7.10", "8.5", "8.6", "10.2", "11.2", "11.3", "12.1", "14.1"] },
    { "id": 4, "tasks": ["12.2", "12.3", "12.4", "13.1", "14.2", "14.3", "15.1", "16.1", "17.1", "19.1", "20.1"] },
    { "id": 5, "tasks": ["13.2", "13.3", "13.4", "14.4", "14.5", "15.2", "15.3", "15.4", "16.2", "17.2", "19.2", "19.3", "20.2", "21.1"] },
    { "id": 6, "tasks": ["13.5", "14.6", "14.7", "21.2", "21.3", "22.1"] }
  ]
}
```
