const crypto = require("crypto");

const TOKEN_VALIDITY_MS = 60 * 1000; // 60 detik
const MAX_TOKEN_HISTORY = 15; // simpan 15 token terakhir

function generateToken() {
  return crypto.randomBytes(3).toString("hex");
}

// Cek apakah token ada & belum expired
function isTokenValid(qrTokens, token) {
  if (!Array.isArray(qrTokens) || !token) return false;
  const now = Date.now();
  return qrTokens.some((t) => t.token === token && t.expiresAt > now);
}

// Rotasi: tambah token baru, buang yang expired
function rotateTokens(qrTokens) {
  const now = Date.now();
  const newToken = {
    token: generateToken(),
    generatedAt: now,
    expiresAt: now + TOKEN_VALIDITY_MS,
  };

  const cleaned = (qrTokens || []).filter((t) => t.expiresAt > now);
  const result = [...cleaned, newToken];

  // Batasi histori biar tidak menumpuk
  if (result.length > MAX_TOKEN_HISTORY) {
    return result.slice(result.length - MAX_TOKEN_HISTORY);
  }
  return result;
}

module.exports = {
  generateToken,
  isTokenValid,
  rotateTokens,
  TOKEN_VALIDITY_MS
};