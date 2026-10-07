const express = require("express");
const {
    db
} = require("../firebase");
const {
    verifyPassword,
    generateToken
} = require("../services/authService");

const router = express.Router();

// POST /api/auth/login
router.post("/login", async (req, res) => {
    const {
        username,
        password
    } = req.body;

    if (!username || !password) {
        return res.status(400).json({
            status: "error",
            message: "Data kurang lengkap"
        });
    }

    try {
        const doc = await db.collection("petugas").doc(username).get();
        if (!doc.exists) {
            return res.status(401).json({
                status: "error",
                message: "Username atau password salah",
            });
        }

        const petugas = doc.data();
        const ok = await verifyPassword(password, petugas.passwordHash);
        if (!ok) {
            return res.status(401).json({
                status: "error",
                message: "Username atau password salah",
            });
        }

        const token = generateToken({
            username,
            role: petugas.role,
            nama: petugas.nama,
        });

        return res.status(200).json({
            token,
            role: petugas.role,
            nama: petugas.nama,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({
            status: "error",
            message: "SERVER_ERROR"
        });
    }
});

module.exports = router;