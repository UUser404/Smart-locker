const {
    verifyToken
} = require("../services/authService");

function requireAuth(req, res, next) {
    const auth = req.headers.authorization;
    if (!auth || !auth.startsWith("Bearer ")) {
        return res.status(401).json({
            status: "error",
            message: "MISSING_TOKEN"
        });
    }

    const token = auth.slice(7);
    try {
        req.user = verifyToken(token);
        next();
    } catch (err) {
        return res.status(401).json({
            status: "error",
            message: "INVALID_TOKEN"
        });
    }
}

function requireRole(...roles) {
    return (req, res, next) => {
        if (!req.user || !roles.includes(req.user.role)) {
            return res.status(403).json({
                status: "error",
                message: "FORBIDDEN"
            });
        }
        next();
    };
}

module.exports = {
    requireAuth,
    requireRole
};