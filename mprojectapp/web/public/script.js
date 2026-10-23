// ============================================================
// Smart Locker - Web Pelanggan
// Sesuai docs/API.md bagian 1-4 (customer flow) & bagian 12 (QR dinamis)
// Backend: https://smart-locker-backend-a2ck.onrender.com/api
// ============================================================

// === KONFIGURASI ===
const kApiBaseUrl = "https://smart-locker-backend-a2ck.onrender.com/api";
const kTimeoutMs = 60000;       // 60s untuk handle Render cold start
const kPollIntervalMs = 3000;   // polling rental status tiap 3 detik

// === STATE ===
const state = {
  lockerId: null,
  token: null,
  rentalId: null,
  uniqueCode: null,
  startedAt: null,
  sessionTimer: null,
};

// === SCREEN NAVIGATION ===
function showScreen(id) {
  document.querySelectorAll(".screen").forEach((el) => el.classList.remove("active"));
  document.getElementById(id).classList.add("active");
}

function backToScanner() {
  stopSessionTimer();
  state.lockerId = null;
  state.token = null;
  state.rentalId = null;
  state.uniqueCode = null;
  state.startedAt = null;
  showScreen("screen-scanner");
  startCamera();
}

// === HELPER: fetch dengan timeout ===
async function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), kTimeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(timeoutId);
    return res;
  } catch (err) {
    clearTimeout(timeoutId);
    if (err.name === "AbortError") {
      throw new Error("Koneksi ke server timeout. Coba lagi.");
    }
    throw new Error("Tidak bisa terhubung ke server. Cek koneksi internet.");
  }
}

// ============================================================
// CAMERA + QR SCANNING
// ============================================================
let videoStream = null;
let scanLoopHandle = null;
let scanBusy = false;    // true selama payload divalidasi ke server
let cameraSession = 0;   // penanda agar startCamera yang tertunda bisa dibatalkan

const kScanIntervalMs = 120;     // ~8 pemindaian/detik sudah cukup untuk QR
const kScanMaxWidth = 1280;      // frame lebih lebar di-downscale sebelum decode
const kRescanCooldownMs = 2000;  // jeda agar QR yang sama tidak langsung terbaca ulang

function setScanStatus(msg) {
  const el = document.getElementById("scan-status");
  if (!el) return;
  el.textContent = msg || "";
  el.hidden = !msg;
}

function cameraErrorMessage(err) {
  switch (err && err.name) {
    case "NotAllowedError":
    case "SecurityError":
      return "Izin kamera ditolak. Aktifkan izin kamera di pengaturan browser lalu muat ulang halaman.";
    case "NotFoundError":
    case "DevicesNotFoundError":
      return "Kamera tidak ditemukan di perangkat ini.";
    case "NotReadableError":
    case "TrackStartError":
      return "Kamera sedang dipakai aplikasi lain. Tutup aplikasi itu lalu coba lagi.";
    default:
      return "Tidak bisa mengakses kamera. Pastikan izin kamera diaktifkan.";
  }
}

async function startCamera() {
  const video = document.getElementById("camera-video");
  const errorEl = document.getElementById("camera-error");
  errorEl.hidden = true;
  setScanStatus("");

  stopCamera(); // cegah stream ganda
  const session = cameraSession;
  scanBusy = false;

  // Pustaka jsQR dari CDN harus sudah termuat
  if (typeof jsQR === "undefined") {
    errorEl.textContent =
      "Pemindai QR gagal dimuat. Cek koneksi internet lalu muat ulang halaman.";
    errorEl.hidden = false;
    return;
  }

  // getUserMedia butuh secure context (HTTPS, localhost, atau 127.0.0.1)
  if (!window.isSecureContext || !navigator.mediaDevices ||
      !navigator.mediaDevices.getUserMedia) {
    errorEl.textContent =
      "Kamera butuh HTTPS (atau localhost). Buka halaman ini lewat HTTPS.";
    errorEl.hidden = false;
    return;
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: { ideal: "environment" },
        width: { ideal: 1280 },
        height: { ideal: 720 },
      },
      audio: false,
    });
    if (session !== cameraSession) {
      // Kamera sudah dihentikan/diganti selagi menunggu izin
      stream.getTracks().forEach((t) => t.stop());
      return;
    }
    videoStream = stream;
    video.srcObject = stream;
    await video.play();
    if (session !== cameraSession) return;
    scanLoop();
  } catch (err) {
    if (session !== cameraSession) return;
    errorEl.textContent = cameraErrorMessage(err);
    errorEl.hidden = false;
  }
}

function stopCamera() {
  cameraSession++; // batalkan startCamera yang masih menunggu
  if (scanLoopHandle) clearTimeout(scanLoopHandle);
  scanLoopHandle = null;
  if (videoStream) {
    videoStream.getTracks().forEach((t) => t.stop());
    videoStream = null;
  }
  const video = document.getElementById("camera-video");
  if (video) video.srcObject = null;
}

function scanLoop() {
  if (scanLoopHandle) return; // sudah berjalan, jangan dobel
  const video = document.getElementById("camera-video");
  const canvas = document.getElementById("camera-canvas");
  const ctx = canvas.getContext("2d", { willReadFrequently: true });

  function tick() {
    scanLoopHandle = null;
    if (!videoStream || scanBusy) return; // berhenti; dilanjutkan oleh resumeScanning()

    if (video.readyState === video.HAVE_ENOUGH_DATA && video.videoWidth > 0) {
      const scale = Math.min(1, kScanMaxWidth / video.videoWidth);
      const w = Math.round(video.videoWidth * scale);
      const h = Math.round(video.videoHeight * scale);
      // Ubah ukuran canvas hanya kalau perlu (mengubahnya mereset canvas)
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
      }
      ctx.drawImage(video, 0, 0, w, h);
      const imageData = ctx.getImageData(0, 0, w, h);
      // QR di layar locker: modul hitam di latar putih, jadi tidak perlu coba inversi
      const code = jsQR(imageData.data, w, h, { inversionAttempts: "dontInvert" });
      if (code && code.data) {
        handleScannedPayload(code.data);
        return;
      }
    }
    scanLoopHandle = setTimeout(tick, kScanIntervalMs);
  }
  scanLoopHandle = setTimeout(tick, kScanIntervalMs);
}

// Lanjut memindai setelah jeda singkat (kamera tetap menyala)
function resumeScanning() {
  scanBusy = true;
  setTimeout(() => {
    if (!videoStream) return; // kamera sudah dihentikan (pindah layar)
    scanBusy = false;
    setScanStatus("");
    scanLoop();
  }, kRescanCooldownMs);
}

// Pindah dari scanner ke layar lain: matikan kamera + status
function leaveScanner(screenId) {
  stopCamera();
  setScanStatus("");
  showScreen(screenId);
}

// === QR PAYLOAD PARSER ===
// Format dari firmware: "locker_01.9f3a1c" (dot-separated)
// Sesuai tft_render.cpp: String(lockerId) + "." + String(token)
function handleScannedPayload(raw) {
  document.getElementById("camera-error").hidden = true;

  const parts = String(raw).trim().split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    showError("QR tidak valid. Pastikan scan QR di layar locker.");
    resumeScanning();
    return;
  }

  scanBusy = true; // hentikan decode; kamera tetap tampil selama server memeriksa
  setScanStatus("Memeriksa QR…");
  const [lockerId, token] = parts;
  validateAndFetchStatus(lockerId, token);
}

// === SCREEN: error generik ===
function showError(msg) {
  const errorEl = document.getElementById("camera-error");
  errorEl.textContent = msg;
  errorEl.hidden = false;
}

// ============================================================
// STEP 1: Validate token + get locker status
// GET /api/lockers/{id}/status?token=xxx
// ============================================================
async function validateAndFetchStatus(lockerId, token) {
  state.lockerId = lockerId;
  state.token = token;

  try {
    const res = await fetchWithTimeout(
      `${kApiBaseUrl}/lockers/${encodeURIComponent(lockerId)}/status?token=${encodeURIComponent(token)}`
    );

    // Respons non-JSON (mis. halaman error dari proxy) tidak boleh membuat crash
    const data = await res.json().catch(() => ({}));

    // Handle error responses
    if (!res.ok) {
      if (data.code === "TOKEN_EXPIRED") {
        leaveScanner("screen-expired");
        return;
      }
      if (data.code === "TOKEN_MISSING") {
        showError("QR tidak valid. Scan ulang.");
        resumeScanning();
        return;
      }
      if (res.status === 404) {
        showError("Locker tidak ditemukan.");
        resumeScanning();
        return;
      }
      showError(data.message || "Gagal memuat status locker.");
      resumeScanning();
      return;
    }

    // Set locker ID di semua screen
    document.getElementById("rent-locker-id").textContent = lockerId;
    document.getElementById("access-locker-id").textContent = lockerId;

    // Render beda screen tergantung status
    if (data.status === "empty") {
      leaveScanner("screen-rent-form");
    } else if (data.status === "occupied") {
      leaveScanner("screen-access-code");
    } else if (data.status === "needs_attention") {
      leaveScanner("screen-needs-attention");
    } else {
      showError("Status locker tidak dikenali.");
      resumeScanning();
    }
  } catch (err) {
    showError(err.message);
    resumeScanning();
  }
}

// ============================================================
// STEP 2: Sewa locker baru
// POST /api/lockers/{id}/rent
// Body: { nama, no_hp, token }
// ============================================================
document.getElementById("form-rent").addEventListener("submit", async (e) => {
  e.preventDefault();
  const nama = document.getElementById("input-nama").value.trim();
  const noHp = document.getElementById("input-no-hp").value.trim();
  const errorEl = document.getElementById("rent-error");
  const submitBtn = e.target.querySelector('button[type="submit"]');

  errorEl.hidden = true;

  if (!nama || !noHp) {
    errorEl.textContent = "Nama dan nomor HP wajib diisi.";
    errorEl.hidden = false;
    return;
  }

  submitBtn.disabled = true;
  submitBtn.textContent = "Memproses...";

  try {
    const res = await fetchWithTimeout(`${kApiBaseUrl}/lockers/${state.lockerId}/rent`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nama, no_hp: noHp, token: state.token }),
    });

    const data = await res.json();

    if (!res.ok) {
      if (data.code === "TOKEN_EXPIRED") {
        showScreen("screen-expired");
        return;
      }
      if (res.status === 409) {
        errorEl.textContent = "Locker sudah terisi orang lain. Scan ulang.";
        errorEl.hidden = false;
        return;
      }
      if (res.status === 429) {
        errorEl.textContent = "Terlalu banyak percobaan, coba lagi nanti.";
        errorEl.hidden = false;
        return;
      }
      errorEl.textContent = data.message || "Gagal memproses sewa.";
      errorEl.hidden = false;
      return;
    }

    state.rentalId = data.rental_id;
    state.uniqueCode = data.unique_code;
    state.startedAt = new Date(data.started_at);

    // Save session ke localStorage (untuk restoration kalau refresh)
    saveSession();

    document.getElementById("unique-code-text").textContent = data.unique_code;
    showScreen("screen-unique-code");
  } catch (err) {
    errorEl.textContent = err.message;
    errorEl.hidden = false;
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "Buka Locker";
  }
});

// === Copy code button ===
document.getElementById("btn-copy-code").addEventListener("click", () => {
  if (!state.uniqueCode) return;
  navigator.clipboard.writeText(state.uniqueCode).then(() => {
    const feedback = document.getElementById("copy-feedback");
    feedback.hidden = false;
    setTimeout(() => (feedback.hidden = true), 2000);
  }).catch(() => {
    // Fallback kalau clipboard tidak tersedia (mis. HTTP non-HTTPS)
    alert("Kode unik: " + state.uniqueCode);
  });
});

// ============================================================
// STEP 3: Access (ambil barang / lanjut sewa)
// POST /api/lockers/{id}/access
// Body: { code, action }
// ============================================================
document.getElementById("form-access").addEventListener("submit", async (e) => {
  e.preventDefault();
  const code = document.getElementById("input-access-code").value.trim().toUpperCase();
  const errorEl = document.getElementById("access-error");
  const submitBtn = e.target.querySelector('button[type="submit"]');

  errorEl.hidden = true;

  if (!code || code.length < 6 || code.length > 8) {
    errorEl.textContent = "Kode harus 6-8 karakter.";
    errorEl.hidden = false;
    return;
  }

  submitBtn.disabled = true;
  submitBtn.textContent = "Memeriksa...";

  try {
    const res = await fetchWithTimeout(`${kApiBaseUrl}/lockers/${state.lockerId}/access`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code, action: "continue" }),
    });

    const data = await res.json();

    if (!res.ok) {
      if (res.status === 400) {
        errorEl.textContent = "Kode tidak valid.";
        errorEl.hidden = false;
        return;
      }
      if (res.status === 429) {
        errorEl.textContent = "Terlalu banyak percobaan, locker dikunci sementara.";
        errorEl.hidden = false;
        return;
      }
      if (res.status === 409) {
        errorEl.textContent = "Locker tidak dalam status disewa.";
        errorEl.hidden = false;
        return;
      }
      errorEl.textContent = data.message || "Gagal membuka locker.";
      errorEl.hidden = false;
      return;
    }

    // Simpan kode untuk aksi "Akhiri Sewa" berikutnya
    state.uniqueCode = code;

    // Coba restore rental_id dari localStorage (kalau user refresh)
    const saved = loadSession();
    if (saved && saved.lockerId === state.lockerId) {
      state.rentalId = saved.rentalId;
      state.startedAt = new Date(saved.startedAt);
    }

    showScreen("screen-access-choice");
  } catch (err) {
    errorEl.textContent = err.message;
    errorEl.hidden = false;
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "Buka Locker";
  }
});

// ============================================================
// STEP 4: Pilihan lanjut / akhiri sewa
// ============================================================
document.querySelector('[data-action="choice-continue"]').addEventListener("click", () => {
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
});

document.querySelector('[data-action="choice-end"]').addEventListener("click", async () => {
  const errorEl = document.getElementById("choice-error");
  errorEl.hidden = true;

  if (!state.uniqueCode) {
    errorEl.textContent = "Kode unik tidak tersedia. Scan ulang QR dan masukkan kode lagi.";
    errorEl.hidden = false;
    return;
  }

  // Kirim action "end" ke backend. Jangan tampilkan "Sewa Selesai" kalau gagal,
  // karena sewa masih berjalan di backend.
  try {
    const res = await fetchWithTimeout(`${kApiBaseUrl}/lockers/${state.lockerId}/access`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: state.uniqueCode, action: "end" }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      errorEl.textContent =
        res.status === 400
          ? "Kode tidak valid. Scan ulang dan masukkan kode lagi."
          : data.message || "Gagal mengakhiri sewa.";
      errorEl.hidden = false;
      return;
    }
  } catch (err) {
    errorEl.textContent = err.message;
    errorEl.hidden = false;
    return;
  }

  // Hitung durasi dari startedAt
  const seconds = state.startedAt
    ? Math.floor((Date.now() - state.startedAt.getTime()) / 1000)
    : 0;

  document.getElementById("ended-duration").textContent = formatDuration(seconds);
  showScreen("screen-session-ended");

  // Clear session
  clearSession();
  state.rentalId = null;
  state.uniqueCode = null;
  state.startedAt = null;
});

// ============================================================
// SESSION PERSISTENCE (localStorage)
// ============================================================
const kSessionKey = "smartlocker_session";

function saveSession() {
  try {
    localStorage.setItem(kSessionKey, JSON.stringify({
      rentalId: state.rentalId,
      lockerId: state.lockerId,
      startedAt: state.startedAt?.toISOString(),
    }));
  } catch (e) {
    console.warn("Gagal save session:", e.message);
  }
}

function loadSession() {
  try {
    const raw = localStorage.getItem(kSessionKey);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (e) {
    return null;
  }
}

function clearSession() {
  try {
    localStorage.removeItem(kSessionKey);
  } catch (e) {
    // Ignore
  }
}

// ============================================================
// SESSION TIMER (polling /rentals/:id/status tiap 3 detik)
// ============================================================
function startSessionTimer() {
  updateSessionDuration();
  stopSessionTimer();
  state.sessionTimer = setInterval(pollRentalStatus, kPollIntervalMs);
}

function stopSessionTimer() {
  if (state.sessionTimer) {
    clearInterval(state.sessionTimer);
    state.sessionTimer = null;
  }
}

async function pollRentalStatus() {
  if (!state.rentalId) {
    // Fallback: kalau tidak ada rental_id, pakai client-side timer
    updateSessionDuration();
    return;
  }

  try {
    const res = await fetchWithTimeout(`${kApiBaseUrl}/rentals/${state.rentalId}/status`);
    if (!res.ok) throw new Error("Polling failed");

    const data = await res.json();

    if (data.rental_status === "completed") {
      // Sesi selesai — tampil durasi akhir
      stopSessionTimer();
      document.getElementById("ended-duration").textContent =
        formatDuration(data.total_duration_seconds);
      showScreen("screen-session-ended");
      clearSession();
      state.rentalId = null;
      state.uniqueCode = null;
      state.startedAt = null;
      return;
    }

    // Update tampilan durasi
    document.getElementById("session-duration").textContent =
      formatDuration(data.elapsed_seconds);
  } catch (err) {
    // Kalau polling gagal, fallback ke client-side timer
    updateSessionDuration();
  }
}

function updateSessionDuration() {
  if (!state.startedAt) return;
  const seconds = Math.floor((Date.now() - state.startedAt.getTime()) / 1000);
  document.getElementById("session-duration").textContent = formatDuration(seconds);
}

function formatDuration(totalSeconds) {
  if (totalSeconds == null) return "00:00:00";
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  return [h, m, s].map((n) => String(n).padStart(2, "0")).join(":");
}

// ============================================================
// BACK TO SCANNER BUTTONS
// ============================================================
document.querySelectorAll('[data-action="back-to-scanner"]').forEach((btn) => {
  btn.addEventListener("click", backToScanner);
});
document.querySelector('[data-action="go-to-session"]').addEventListener("click", () => {
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
});

// ============================================================
// DEV SIMULATION (hidden by default, aktif kalau URL ada ?dev=1)
// ============================================================
if (new URLSearchParams(location.search).get("dev") === "1") {
  const devTools = document.querySelector(".dev-tools");
  if (devTools) devTools.hidden = false;

  document.querySelectorAll("[data-sim]").forEach((btn) => {
    btn.addEventListener("click", () => {
      stopCamera();
      const sim = btn.dataset.sim;
      if (sim === "expired") {
        showScreen("screen-expired");
        return;
      }
      // Simulasi status
      document.getElementById("rent-locker-id").textContent = "locker_01";
      document.getElementById("access-locker-id").textContent = "locker_01";
      state.lockerId = "locker_01";
      state.token = "sim-token";

      if (sim === "empty") showScreen("screen-rent-form");
      else if (sim === "occupied") showScreen("screen-access-code");
      else if (sim === "needs_attention") showScreen("screen-needs-attention");
    });
  });
} else {
  // Sembunyikan dev tools by default
  const devTools = document.querySelector(".dev-tools");
  if (devTools) devTools.hidden = true;
}

// ============================================================
// INIT
// ============================================================
// Cek apakah ada session tersimpan → kalau ada, restore ke screen session active
const savedSession = loadSession();
if (savedSession && savedSession.rentalId && savedSession.lockerId) {
  state.rentalId = savedSession.rentalId;
  state.lockerId = savedSession.lockerId;
  state.startedAt = new Date(savedSession.startedAt);
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
} else {
  // Default: scanner
  startCamera();
}