const jwt = require("jsonwebtoken");
const User = require("../models/User");

async function adminAuthMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.split(" ")[1]
      : null;

    if (!token) {
      return res.status(401).json({ message: "Missing Bearer token" });
    }

    const secret = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET;
    if (!secret) {
      return res.status(500).json({ message: "Admin JWT secret is not configured" });
    }

    const decoded = jwt.verify(token, secret);
    const user = await User.findById(decoded.sub);

    if (!user) {
      return res.status(401).json({ message: "Admin user not found" });
    }

    if (user.isActive === false) {
      return res.status(403).json({ message: "Admin account is disabled" });
    }

    if (user.role !== "admin") {
      return res.status(403).json({ message: "Admin access required" });
    }

    req.adminUser = user;
    req.adminToken = decoded;

    return next();
  } catch (err) {
    return res.status(401).json({
      message: "Invalid/expired admin token",
      error: String(err),
    });
  }
}

module.exports = adminAuthMiddleware;
