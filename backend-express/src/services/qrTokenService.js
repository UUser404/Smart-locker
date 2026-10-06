const crypto = require("crypto");

// Token format: 6 karakter hex (cth: "9f3a1c")
function generateToken() {
  return crypto.randomBytes(3).toString("hex");
}

// Cek apakah token ada di histori & belum expired
function isTokenValid(qrTokens, token) {
  if (!Array.isArray(qrTokens) || !token) return false;
  const now = Date.now();
  return qrTokens.some((t) => t.token === token && t.expiresAt > now);
}

module.exports = { generateToken, isTokenValid };
