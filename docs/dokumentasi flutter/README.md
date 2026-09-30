\# Dokumentasi Setup Flutter \& Android Toolchain



Catatan lengkap proses troubleshooting `flutter doctor` sampai berhasil, plus cara membuat project baru dengan package name custom.



\---



\## 1. Masalah Awal: Android License Status Unknown



Saat menjalankan:

```

flutter doctor

```

Muncul error:

```

\[!] Android toolchain - develop for Android devices (Android SDK version 36.0.0)

&#x20;   X Android license status unknown.

&#x20;     Run `flutter doctor --android-licenses` to accept the SDK licenses.

```



\## 2. Percobaan Pertama (Gagal — cmdline-tools terlalu baru)



```

flutter doctor --android-licenses

```

Hasil: muncul warning bahwa `sdkmanager` sudah deprecated dan `--licenses` "no longer needed" — cmdline-tools versi terbaru sudah tidak kompatibel dengan cara lama Flutter menerima lisensi.



\## 3. Downgrade cmdline-tools lewat Android Studio



1\. Buka \*\*Android Studio\*\*

2\. \*\*File → Settings → Languages \& Frameworks → Android SDK\*\*

3\. Tab \*\*SDK Tools\*\*

4\. Centang \*\*Show Package Details\*\*

5\. Di \*\*Android SDK Command-line Tools\*\*, uninstall versi terbaru

6\. Install versi lama, misalnya `12.0`

7\. Klik \*\*Apply\*\*



\### Kendala saat download:

\- Error `Not in GZIP format` → biasanya download corrupt, cukup retry.

\- Error `Read timed out` → masalah koneksi ke server Google, retry beberapa kali atau pakai jaringan lain.



\## 4. Error Java Version saat Jalankan sdkmanager Manual



```

"%LOCALAPPDATA%\\Android\\sdk\\cmdline-tools\\12.0\\bin\\sdkmanager.bat" --licenses

```

Muncul:

```

Java version 17 or higher is required.

```



\### Solusi sementara (per sesi terminal):

```

set JAVA\_HOME=C:\\Program Files\\Android\\Android Studio\\jbr

"%LOCALAPPDATA%\\Android\\sdk\\cmdline-tools\\12.0\\bin\\sdkmanager.bat" --licenses

```

Setelah itu ketik `y` untuk setiap lisensi yang muncul, sampai keluar pesan:

```

All SDK package licenses accepted

```



\## 5. Set JAVA\_HOME Permanen (System Environment Variable)



1\. `Win + R` → ketik `sysdm.cpl` → Enter

2\. Tab \*\*Advanced\*\* → \*\*Environment Variables...\*\*

3\. Di \*\*System variables\*\* → \*\*New...\*\*

&#x20;  - Variable name: `JAVA\_HOME`

&#x20;  - Variable value: `C:\\Program Files\\Android\\Android Studio\\jbr`

4\. \*\*OK\*\* di semua jendela

5\. Buka terminal \*\*baru\*\*, verifikasi:

&#x20;  ```

&#x20;  echo %JAVA\_HOME%

&#x20;  ```

&#x20;  Harus menampilkan path JDK di atas.



\## 6. Root Cause Sebenarnya: Folder `latest` vs `12.0`



Setelah lisensi ter-accept, `flutter doctor` \*\*masih\*\* menampilkan `Android license status unknown`.



Penyebab: di folder `cmdline-tools` ada dua versi:

```

cmdline-tools\\

&#x20; ├── 12.0      ← sudah berhasil accept lisensi

&#x20; └── latest    ← versi baru/deprecated, dipakai otomatis oleh Flutter

```

Flutter selalu memprioritaskan folder `latest`, sehingga status accept di folder `12.0` tidak terbaca.



\### Fix: ganti isi folder `latest` dengan isi folder `12.0`

```

ren "C:\\Users\\User\\AppData\\Local\\Android\\sdk\\cmdline-tools\\latest" "latest\_old"

xcopy "C:\\Users\\User\\AppData\\Local\\Android\\sdk\\cmdline-tools\\12.0" "C:\\Users\\User\\AppData\\Local\\Android\\sdk\\cmdline-tools\\latest" /E /I

```



\## 7. Verifikasi Akhir



```

flutter doctor --android-licenses

flutter doctor

```



Hasil akhir:

```

\[√] Flutter

\[√] Windows Version

\[√] Android toolchain - develop for Android devices (Android SDK version 36.0.0)

\[√] Chrome - develop for the web

\[X] Visual Studio - develop Windows apps      ← opsional, hanya perlu jika target Windows desktop

\[√] Android Studio

\[√] VS Code

\[√] Connected device

\[√] Network resources

```



Android toolchain sudah `√` — siap develop aplikasi Android.



\---



\## 8. Membuat Project Flutter Baru dengan Package Name Custom



Dijalankan di \*\*Command Prompt / PowerShell\*\*, bukan di editor kode.



\### Langkah:

1\. Pindah ke folder tempat menyimpan project:

&#x20;  ```

&#x20;  cd C:\\Users\\User\\Documents\\FlutterProjects

&#x20;  ```

&#x20;  (buat dulu foldernya jika belum ada: `mkdir C:\\Users\\User\\Documents\\FlutterProjects`)



2\. Jalankan create project — `--org` diisi domain saja, argumen terakhir adalah \*\*nama project\*\* (bukan package lengkap):

&#x20;  ```

&#x20;  flutter create --org com.smartlocker mprojectapp

&#x20;  ```

&#x20;  Flutter otomatis menyusun package menjadi `com.smartlocker.mprojectapp`.



3\. Masuk ke folder project:

&#x20;  ```

&#x20;  cd mprojectapp

&#x20;  ```



4\. (Opsional) buka di VS Code:

&#x20;  ```

&#x20;  code .

&#x20;  ```



\### Mengubah package name di project yang sudah ada

Jika project sudah dibuat dan ingin ganti package name, pakai tool `rename` (lebih aman dari edit manual):

```

dart pub global activate rename

rename setAppId --targets android --value "com.smartlocker.mprojectapp"

```

Lalu bersihkan cache build:

```

flutter clean

flutter pub get

```



File yang terpengaruh jika edit manual:

\- `android/app/build.gradle.kts` → `namespace` dan `applicationId`

\- `android/app/src/main/kotlin/.../MainActivity.kt` → baris `package ...` di atas, plus struktur folder harus disesuaikan

