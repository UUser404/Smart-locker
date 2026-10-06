const crypto = require("crypto");

// Charset tanpa 0/O/1/I biar user gampang baca
const CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;

function generateUniqueCode() {
  let code = "";
  const bytes = crypto.randomBytes(CODE_LENGTH);
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CHARSET[bytes[i] % CHARSET.length];
  }
  return code;
}

function hashCode(code) {
  return crypto
    .createHash("sha256")
    .update(String(code).toUpperCase())
    .digest("hex");
}

function verifyCode(inputCode, storedHash) {
  return hashCode(inputCode) === storedHash;
}

module.exports = { generateUniqueCode, hashCode, verifyCode };
