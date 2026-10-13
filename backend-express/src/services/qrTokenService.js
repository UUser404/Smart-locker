const crypto = require("crypto");

// Generate token acak 6 karakter hex
function generateToken() {
  return crypto.randomBytes(3).toString("hex");
}

module.exports = {
  generateToken
};