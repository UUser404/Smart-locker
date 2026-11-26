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
  lockerStatus: null,
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

function backToHome() {
  stopSessionTimer();
  state.lockerId = null;
  state.lockerStatus = null;
  state.token = null;
  state.rentalId = null;
  state.uniqueCode = null;
  state.startedAt = null;
  const currentUrl = new URL(window.location.href);
  if (currentUrl.searchParams.has("token")) {
    currentUrl.pathname = "/";
    currentUrl.search = "";
    currentUrl.hash = "";
    window.history.replaceState(null, "", currentUrl.href);
  }
  document.getElementById("page-error").hidden = true;
  showScreen("screen-home");
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

async function readResponseJson(res) {
  try {
    const data = await res.json();
    if (!data || typeof data !== "object" || Array.isArray(data)) {
      throw new Error("Respons layanan tidak dapat dibaca. Coba lagi.");
    }
    return data;
  } catch {
    if (!res.ok) return {};
    throw new Error("Respons layanan tidak dapat dibaca. Coba lagi.");
  }
}

// === QR PAYLOAD PARSER ===
// QR firmware berisi link frontend dengan identitas locker dan token dinamis.
function handleScannedPayload(raw) {
  document.getElementById("page-error").hidden = true;

  const payload = String(raw).trim();
  let lockerId;
  let token;

  try {
    const url = new URL(payload);
    if (url.protocol === "https:" || url.protocol === "http:") {
      const pathParts = url.pathname.split("/").filter(Boolean);
      if (pathParts.length > 0) {
        lockerId = decodeURIComponent(pathParts[pathParts.length - 1]);
        token = url.searchParams.get("token");
      }
    }
  } catch (err) {
    // QR text lama berbentuk lockerId.token; tetap diterima untuk kompatibilitas.
  }

  if (!lockerId && !token) {
    // Keep accepting legacy dot-separated payloads during firmware rollout.
    const parts = payload.split(".");
    if (parts.length === 2) {
      lockerId = parts[0];
      token = parts[1];
    }
  }

  if (!lockerId || !token) {
    showError("Tautan QR tidak lengkap. Pindai QR pada locker sekali lagi.");
    return;
  }

  validateAndFetchStatus(lockerId, token);
}

// === SCREEN: error generik ===
function showError(msg) {
  const errorEl = document.getElementById("page-error");
  errorEl.textContent = msg;
  errorEl.hidden = false;
  showScreen("screen-home");
}

function customerErrorMessage(data, status, fallback) {
  const code = data.code || data.message;
  const messages = {
    TOKEN_MISSING: "Tautan QR tidak lengkap. Pindai QR pada locker sekali lagi.",
    TOKEN_EXPIRED: "QR sudah diperbarui. Pindai QR terbaru pada locker.",
    LOCKER_NOT_FOUND: "Locker tidak ditemukan. Pastikan kamu membuka QR yang benar.",
    LOCKER_NOT_EMPTY: "Locker sudah digunakan. Silakan pilih locker lain.",
    LOCKER_NOT_OCCUPIED:
      "Sewa locker ini sudah tidak aktif. Pindai QR lagi atau minta bantuan petugas.",
    NO_ACTIVE_RENTAL: "Sesi sewa tidak ditemukan. Minta bantuan petugas locker.",
    RENTAL_NOT_FOUND: "Data sewa tidak ditemukan. Minta bantuan petugas locker.",
    INVALID_CODE: "Kode tidak cocok. Periksa kembali kode unik kamu.",
    ACTION_INVALID: "Permintaan ini tidak dapat diproses. Coba lagi.",
    SERVER_ERROR: "Layanan sedang bermasalah. Coba lagi beberapa saat.",
  };

  if (status === 429) {
    return "Terlalu banyak percobaan. Tunggu sebentar sebelum mencoba lagi.";
  }
  if (status >= 500) {
    return messages.SERVER_ERROR;
  }
  return Object.prototype.hasOwnProperty.call(messages, code)
    ? messages[code]
    : fallback;
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
    const data = await readResponseJson(res);

    // Handle error responses
    if (!res.ok) {
      if (data.code === "TOKEN_EXPIRED") {
        showScreen("screen-expired");
        return;
      }
      if (data.code === "TOKEN_MISSING") {
        showError(customerErrorMessage(data, res.status, "Tautan QR tidak lengkap."));
        return;
      }
      showError(customerErrorMessage(
        data,
        res.status,
        "Status locker belum dapat dimuat. Coba pindai QR lagi.",
      ));
      return;
    }

    // Set locker ID di semua screen
    document.getElementById("rent-locker-id").textContent = lockerId;
    document.getElementById("access-locker-id").textContent = lockerId;
    state.lockerStatus = data.status;
    document.getElementById("access-status-label").textContent =
      data.status === "needs_attention" ? "perlu diperiksa" : "sedang disewa";
    document.getElementById("access-hint").textContent =
      data.status === "needs_attention"
        ? "Locker ini tidak dapat disewa. Masukkan kode unik untuk mengambil barang dan mengakhiri sewa."
        : "Masukkan kode unik untuk membuka locker dan mengambil barangmu.";

    // Render beda screen tergantung status
    if (data.status === "empty") {
      showScreen("screen-rent-form");
    } else if (data.status === "occupied") {
      showScreen("screen-access-code");
    } else if (data.status === "needs_attention") {
      showScreen("screen-needs-attention");
    } else {
      showError("Status locker belum dapat ditampilkan. Coba pindai QR lagi.");
    }
  } catch (err) {
    showError(err.message || "Layanan sedang bermasalah. Coba lagi beberapa saat.");
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

    const data = await readResponseJson(res);

    if (!res.ok) {
      if (data.code === "TOKEN_EXPIRED") {
        showScreen("screen-expired");
        return;
      }
      if (res.status === 409) {
        errorEl.textContent = customerErrorMessage(
          data,
          res.status,
          "Locker sudah digunakan orang lain. Pindai QR terbaru untuk mencoba lagi.",
        );
        errorEl.hidden = false;
        return;
      }
      errorEl.textContent = customerErrorMessage(
        data,
        res.status,
        "Sewa belum dapat diproses. Coba lagi beberapa saat.",
      );
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

    const data = await readResponseJson(res);

    if (!res.ok) {
      errorEl.textContent = customerErrorMessage(
        data,
        res.status,
        "Locker belum dapat dibuka. Periksa kode atau minta bantuan petugas.",
      );
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

    const continueButton = document.querySelector('[data-action="choice-continue"]');
    const choiceHint = document.getElementById("choice-hint");
    continueButton.hidden = state.lockerStatus === "needs_attention";
    choiceHint.textContent = state.lockerStatus === "needs_attention"
      ? "Locker perlu diperiksa. Ambil barang lalu akhiri sewa."
      : "Pilih untuk melanjutkan sewa atau mengakhiri sewa setelah mengambil barang.";
    showScreen("screen-access-choice");
  } catch (err) {
    errorEl.textContent = err.message || "Layanan sedang bermasalah. Coba lagi.";
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
  if (state.lockerStatus === "needs_attention") return;
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
});

document.querySelector('[data-action="choice-end"]').addEventListener("click", async () => {
  const errorEl = document.getElementById("choice-error");
  const endButton = document.querySelector('[data-action="choice-end"]');
  errorEl.hidden = true;

  if (!state.uniqueCode) {
    errorEl.textContent = "Kode unik tidak tersedia. Pindai QR locker dan masukkan kode lagi.";
    errorEl.hidden = false;
    return;
  }

  // Tampilkan status selesai hanya setelah sistem mengonfirmasi pintu tertutup.
  endButton.disabled = true;
  try {
    const res = await fetchWithTimeout(`${kApiBaseUrl}/lockers/${state.lockerId}/access`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: state.uniqueCode, action: "end" }),
    });
    const data = await readResponseJson(res);
    if (!res.ok) {
      errorEl.textContent = customerErrorMessage(
        data,
        res.status,
        "Sewa belum dapat diakhiri. Coba lagi atau minta bantuan petugas.",
      );
      errorEl.hidden = false;
      return;
    }
  } catch (err) {
    errorEl.textContent = err.message || "Layanan sedang bermasalah. Coba lagi.";
    errorEl.hidden = false;
    return;
  } finally {
    endButton.disabled = false;
  }

  const endingStatus = document.getElementById("ending-status");
  endingStatus.textContent = state.rentalId
    ? "Permintaan diterima. Pastikan pintu tertutup; status sewa akan diperbarui otomatis setelah locker terkonfirmasi."
    : "Permintaan diterima. Pastikan pintu tertutup. Status sewa belum dapat diperiksa dari perangkat ini; hubungi petugas jika belum berubah.";
  showScreen("screen-session-ending");
  if (state.rentalId) startSessionTimer();
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

    const data = await readResponseJson(res);

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
    if (document.getElementById("screen-session-ending").classList.contains("active")) {
      document.getElementById("ending-status").textContent =
        "Permintaan diterima. Sistem belum dapat memastikan pintu sudah tertutup. Status akan diperbarui otomatis setelah konfirmasi tersedia.";
      return;
    }

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
// Kembali ke halaman awal untuk memindai QR dengan kamera ponsel.
// ============================================================
document.querySelectorAll('[data-action="back-to-home"]').forEach((btn) => {
  btn.addEventListener("click", backToHome);
});
document.querySelector('[data-action="go-to-session"]').addEventListener("click", () => {
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
});
document.querySelector('[data-action="attention-access"]').addEventListener("click", () => {
  document.getElementById("access-status-label").textContent = "perlu diperiksa";
  document.getElementById("access-hint").textContent =
    "Locker ini tidak dapat disewa. Masukkan kode unik untuk mengambil barang dan mengakhiri sewa.";
  showScreen("screen-access-code");
});

// ============================================================
// DEV SIMULATION (hidden by default, aktif kalau URL ada ?dev=1)
// ============================================================
if (new URLSearchParams(location.search).get("dev") === "1") {
  const devTools = document.querySelector(".dev-tools");
  if (devTools) devTools.hidden = false;

  document.querySelectorAll("[data-sim]").forEach((btn) => {
    btn.addEventListener("click", () => {
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
      state.lockerStatus = sim === "needs_attention" ? "needs_attention" :
        sim === "occupied" ? "occupied" : "empty";

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
const currentUrl = new URL(window.location.href);
const currentPathParts = currentUrl.pathname.split("/").filter(Boolean);
const openedFromLockerQr =
  currentPathParts.length > 0 && currentUrl.searchParams.has("token");

if (openedFromLockerQr) {
  handleScannedPayload(currentUrl.href);
} else if (savedSession && savedSession.rentalId && savedSession.lockerId) {
  state.rentalId = savedSession.rentalId;
  state.lockerId = savedSession.lockerId;
  state.startedAt = new Date(savedSession.startedAt);
  document.getElementById("session-locker-id").textContent = state.lockerId;
  showScreen("screen-session-active");
  startSessionTimer();
}