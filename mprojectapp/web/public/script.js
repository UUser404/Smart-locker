// ============================================================
// Smart Locker - Web Pelanggan
// Sesuai docs/API.md bagian 1-4 (customer flow) & bagian 12 (QR dinamis)
//
// kUseMockData: true selama backend asli belum ada. Semua fungsi di
// MockBackend mensimulasikan response backend in-memory (reset tiap
// reload halaman). Ganti fetchFromBackend() di bagian bawah untuk
// pindah ke backend asli nanti.
// ============================================================

const kUseMockData = true;
const kApiBaseUrl = "https://<domain-backend>/api";

// ---------------------------------------------------------
// State
// ---------------------------------------------------------
const state = {
  lockerId: null,
  token: null,
  rentalId: null,
  uniqueCode: null,
  startedAt: null,
  sessionTimer: null,
};

// ---------------------------------------------------------
// Screen navigation
// ---------------------------------------------------------
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

// ---------------------------------------------------------
// Camera + QR scanning
// ---------------------------------------------------------
let videoStream = null;
let scanLoopHandle = null;

async function startCamera() {
  const video = document.getElementById("camera-video");
  const errorEl = document.getElementById("camera-error");
  errorEl.hidden = true;

  try {
    videoStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "environment" },
    });
    video.srcObject = videoStream;
    await video.play();
    scanLoop();
  } catch (err) {
    errorEl.textContent =
      "Tidak bisa mengakses kamera. Pastikan izin kamera diaktifkan, atau gunakan tombol simulasi di bawah untuk mencoba alur tanpa kamera.";
    errorEl.hidden = false;
  }
}

function stopCamera() {
  if (scanLoopHandle) cancelAnimationFrame(scanLoopHandle);
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
        return; // stop loop, a screen transition will restart it if needed
      }
    }
    scanLoopHandle = requestAnimationFrame(tick);
  }
  scanLoopHandle = requestAnimationFrame(tick);
}

// QR payload format (disepakati dengan firmware/backend):
// {"locker_id":"locker_01","token":"AbC123XyZ"}
function handleScannedPayload(raw) {
  stopCamera();
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch (e) {
    // QR bukan format yang diharapkan -> anggap invalid, balik ke scanner
    startCamera();
    return;
  }
  validateAndFetchStatus(payload.locker_id, payload.token);
}

// ---------------------------------------------------------
// Dev simulation buttons (no camera needed)
// ---------------------------------------------------------
document.querySelectorAll("[data-sim]").forEach((btn) => {
  btn.addEventListener("click", () => {
    stopCamera();
    const sim = btn.dataset.sim;
    if (sim === "expired") {
      showScreen("screen-expired");
      return;
    }
    validateAndFetchStatus("locker_0" + (1 + Math.floor(Math.random() * 4)), "sim-token", sim);
  });
});

// ---------------------------------------------------------
// Step 1: validate token + get locker status
// GET /api/lockers/{locker_id}/status  (token dilampirkan sbg query param)
// ---------------------------------------------------------
async function validateAndFetchStatus(lockerId, token, forceStatus) {
  state.lockerId = lockerId;
  state.token = token;

  try {
    const res = forceStatus
      ? { status: forceStatus, locker_id: lockerId }
      : await MockBackend.getStatus(lockerId, token);

    document.getElementById("rent-locker-id").textContent = lockerId;
    document.getElementById("access-locker-id").textContent = lockerId;

    if (res.status === "empty") {
      showScreen("screen-rent-form");
    } else if (res.status === "occupied") {
      showScreen("screen-access-code");
    } else if (res.status === "needs_attention") {
      showScreen("screen-needs-attention");
    }
  } catch (err) {
    if (err.code === "TOKEN_EXPIRED") {
      showScreen("screen-expired");
    } else if (err.code === "CONCURRENT_REQUEST") {
      showScreen("screen-queue");
    } else {
      showScreen("screen-expired");
    }
  }
}

// ---------------------------------------------------------
// Step 2: rent form submit
// POST /api/lockers/{locker_id}/rent
// ---------------------------------------------------------
document.getElementById("form-rent").addEventListener("submit", async (e) => {
  e.preventDefault();
  const nama = document.getElementById("input-nama").value.trim();
  const noHp = document.getElementById("input-no-hp").value.trim();
  const errorEl = document.getElementById("rent-error");
  errorEl.hidden = true;

  try {
    const res = await MockBackend.rent(state.lockerId, state.token, nama, noHp);
    state.rentalId = res.rental_id;
    state.uniqueCode = res.unique_code;
    state.startedAt = new Date(res.started_at);

    document.getElementById("unique-code-text").textContent = res.unique_code;
    showScreen("screen-unique-code");
  } catch (err) {
    errorEl.textContent =
      err.code === "LOCKER_TAKEN"
        ? "Locker sudah terisi orang lain. Silakan scan ulang."
        : err.code === "CONCURRENT_REQUEST"
        ? "Sedang dalam antrian, silakan coba lagi."
        : "Gagal memproses sewa. Coba lagi.";
    errorEl.hidden = false;
  }
});

document.getElementById("btn-copy-code").addEventListener("click", () => {
  navigator.clipboard.writeText(state.uniqueCode).then(() => {
    const feedback = document.getElementById("copy-feedback");
    feedback.hidden = false;
    setTimeout(() => (feedback.hidden = true), 2000);
  });
});

// ---------------------------------------------------------
// Step 3: access form submit (locker occupied -> enter unique code)
// POST /api/lockers/{locker_id}/access
// ---------------------------------------------------------
document.getElementById("form-access").addEventListener("submit", async (e) => {
  e.preventDefault();
  const code = document.getElementById("input-access-code").value.trim().toUpperCase();
  const errorEl = document.getElementById("access-error");
  errorEl.hidden = true;

  try {
    const res = await MockBackend.access(state.lockerId, code, "continue");
    state.rentalId = res.rental_id;
    state.startedAt = res.started_at ? new Date(res.started_at) : new Date();
    showScreen("screen-access-choice");
  } catch (err) {
    errorEl.textContent = "Kode tidak valid.";
    errorEl.hidden = false;
  }
});

// ---------------------------------------------------------
// Step 4: pilihan lanjut / akhiri sewa
// ---------------------------------------------------------
document.querySelector('[data-action="choice-continue"]').addEventListener("click", () => {
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
});

document.querySelector('[data-action="choice-end"]').addEventListener("click", async () => {
  const res = await MockBackend.access(state.lockerId, null, "end", state.rentalId);
  document.getElementById("ended-duration").textContent = formatDuration(res.total_duration_seconds);
  showScreen("screen-session-ended");
});

// ---------------------------------------------------------
// Session timer (durasi berjalan, model parkir)
// GET /api/rentals/{rental_id}/status dipoll tiap 3 detik di implementasi
// asli; di mock ini dihitung langsung dari startedAt di client.
// ---------------------------------------------------------
function startSessionTimer() {
  updateSessionDuration();
  state.sessionTimer = setInterval(updateSessionDuration, 1000);
}

function stopSessionTimer() {
  if (state.sessionTimer) {
    clearInterval(state.sessionTimer);
    state.sessionTimer = null;
  }
}

function updateSessionDuration() {
  if (!state.startedAt) return;
  const seconds = Math.floor((Date.now() - state.startedAt.getTime()) / 1000);
  document.getElementById("session-duration").textContent = formatDuration(seconds);
}

function formatDuration(totalSeconds) {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  return [h, m, s].map((n) => String(n).padStart(2, "0")).join(":");
}

// ---------------------------------------------------------
// Generic back-to-scanner buttons
// ---------------------------------------------------------
document.querySelectorAll('[data-action="back-to-scanner"]').forEach((btn) => {
  btn.addEventListener("click", backToScanner);
});
document.querySelector('[data-action="go-to-session"]').addEventListener("click", () => {
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
});

// ---------------------------------------------------------
// MockBackend — mensimulasikan endpoint di docs/API.md
// Ganti isi tiap fungsi dengan fetch() ke kApiBaseUrl saat backend asli siap.
// ---------------------------------------------------------
const MockBackend = {
  async getStatus(lockerId, token) {
    await delay(300);
    if (token === "expired-token") {
      const err = new Error("expired");
      err.code = "TOKEN_EXPIRED";
      throw err;
    }
    // Demo: status ditentukan acak kecuali dari tombol simulasi
    return { locker_id: lockerId, status: "empty" };
  },

  async rent(lockerId, token, nama, noHp) {
    await delay(500);
    const code = generateUniqueCode();
    return {
      status: "ok",
      rental_id: "rnt_" + Date.now(),
      unique_code: code,
      started_at: new Date().toISOString(),
    };
  },

  async access(lockerId, code, action, existingRentalId) {
    await delay(400);
    if (action === "end") {
      const startedAt = state.startedAt || new Date();
      const seconds = Math.floor((Date.now() - startedAt.getTime()) / 1000);
      return {
        status: "ok",
        action: "end",
        total_duration_seconds: seconds,
      };
    }
    if (!code || code.length < 4) {
      const err = new Error("invalid code");
      err.code = "INVALID_CODE";
      throw err;
    }
    return {
      status: "ok",
      action: "continue",
      unlocked: true,
      rental_id: existingRentalId || "rnt_existing",
      started_at: state.startedAt ? state.startedAt.toISOString() : new Date().toISOString(),
    };
  },
};

function generateUniqueCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------
// Init
// ---------------------------------------------------------
startCamera();