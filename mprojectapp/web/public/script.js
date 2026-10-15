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

async function startCamera() {
  const video = document.getElementById("camera-video");
  const errorEl = document.getElementById("camera-error");
  errorEl.hidden = true;

  // HTTPS check (getUserMedia butuh HTTPS atau localhost)
  if (location.protocol !== "https:" && location.hostname !== "localhost") {
    errorEl.textContent =
      "Kamera butuh koneksi HTTPS. Buka halaman ini lewat HTTPS.";
    errorEl.hidden = false;
    return;
  }

  try {
    videoStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "environment" },
    });
    video.srcObject = videoStream;
    await video.play();
    scanLoop();
  } catch (err) {
    errorEl.textContent =
      "Tidak bisa mengakses kamera. Pastikan izin kamera diaktifkan.";
    errorEl.hidden = false;
  }
}

function stopCamera() {
  if (scanLoopHandle) cancelAnimationFrame(scanLoopHandle);
  scanLoopHandle = null;
  if (videoStream) {
    videoStream.getTracks().forEach((t) => t.stop());
    videoStream = null;
  }
}

function scanLoop() {
  const video = document.getElementById("camera-video");
  const canvas = document.getElementById("camera-canvas");
  const ctx = canvas.getContext("2d");

  function tick() {
    if (video.readyState === video.HAVE_ENOUGH_DATA) {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const code = jsQR(imageData.data, imageData.width, imageData.height);
      if (code) {
        handleScannedPayload(code.data);
        return;
      }
    }
    scanLoopHandle = requestAnimationFrame(tick);
  }
  scanLoopHandle = requestAnimationFrame(tick);
}

// === QR PAYLOAD PARSER ===
// Format dari firmware: "locker_01.9f3a1c" (dot-separated)
// Sesuai tft_render.cpp: String(lockerId) + "." + String(token)
function handleScannedPayload(raw) {
  stopCamera();

  const parts = raw.trim().split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    showError("QR tidak valid. Pastikan scan QR di layar locker.");
    startCamera();
    return;
  }

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

    const data = await res.json();

    // Handle error responses
    if (!res.ok) {
      if (data.code === "TOKEN_EXPIRED") {
        showScreen("screen-expired");
        return;
      }
      if (data.code === "TOKEN_MISSING") {
        showError("QR tidak valid. Scan ulang.");
        startCamera();
        return;
      }
      if (res.status === 404) {
        showError("Locker tidak ditemukan.");
        startCamera();
        return;
      }
      showError(data.message || "Gagal memuat status locker.");
      startCamera();
      return;
    }

    // Set locker ID di semua screen
    document.getElementById("rent-locker-id").textContent = lockerId;
    document.getElementById("access-locker-id").textContent = lockerId;

    // Render beda screen tergantung status
    if (data.status === "empty") {
      showScreen("screen-rent-form");
    } else if (data.status === "occupied") {
      showScreen("screen-access-code");
    } else if (data.status === "needs_attention") {
      showScreen("screen-needs-attention");
    } else {
      showError("Status locker tidak dikenali.");
      startCamera();
    }
  } catch (err) {
    showError(err.message);
    startCamera();
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
  // Kirim action "end" ke backend
  try {
    await fetchWithTimeout(`${kApiBaseUrl}/lockers/${state.lockerId}/access`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: state.uniqueCode || "UNKNOWN", action: "end" }),
    });
  } catch (err) {
    // Kalau gagal, tetap lanjut tampil durasi dari state (user sudah di depan locker)
    console.warn("Access end gagal:", err.message);
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