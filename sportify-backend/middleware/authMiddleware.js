const initFirebaseAdmin = require("../config/firebaseAdmin");
const admin = initFirebaseAdmin();

async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.split(" ")[1]
      : null;

    if (!token) {
      return res.status(401).json({ message: "Missing Bearer token" });
    }

    const decoded = await admin.auth().verifyIdToken(token);

    // Attach firebase user to request
    req.firebase = {
      uid: decoded.uid,
      email: decoded.email || null,
      name: decoded.name || null,
      picture: decoded.picture || null,
    };

    next();
  } catch (err) {
    return res.status(401).json({ message: "Invalid/expired token", error: String(err) });
  }
}

module.exports = authMiddleware;
