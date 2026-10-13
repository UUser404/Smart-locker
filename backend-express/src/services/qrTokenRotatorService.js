const tokenStore = require("./tokenStoreService");

async function rotateAllTokens(db) {
    // db tidak dipakai lagi — argumen tetap ada untuk backward compat
    const count = tokenStore.rotateAll();
    return count;
}

module.exports = {
    rotateAllTokens
};