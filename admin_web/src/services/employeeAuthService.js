import { collection, query, where, getDocs } from "firebase/firestore";
import { db } from "../firebase";
import sha256 from "crypto-js/sha256";

/**
 * =====================================================
 *   Đăng nhập nhân viên (role = staff)
 * =====================================================
 */
export async function employeeLogin(identifier, password) {
  try {
    const hashed = sha256(password).toString();

    let q;

    // Email
    if (identifier.includes("@")) {
      q = query(
        collection(db, "users"),
        where("email", "==", identifier),
        where("password", "==", hashed),
        where("role", "==", "staff")
      );
    }

    // Phone
    else if (/^[0-9]+$/.test(identifier)) {
      q = query(
        collection(db, "users"),
        where("phone", "==", identifier),
        where("password", "==", hashed),
        where("role", "==", "staff")
      );
    }

    // Username
    else {
      q = query(
        collection(db, "users"),
        where("username", "==", identifier),
        where("password", "==", hashed),
        where("role", "==", "staff")
      );
    }

    const snap = await getDocs(q);
    if (snap.empty) return null;

    const staff = snap.docs[0];
    return { id: staff.id, ...staff.data() };

  } catch (err) {
    console.error("Employee Login Error:", err);
    return null;
  }
}

/**
 * =====================================================
 *   Lấy IP Public (đồng bộ với userService → getIP)
 * =====================================================
 */
export async function getIP() {
  try {
    const res = await fetch("https://api.ipify.org?format=json");
    const data = await res.json();
    return data.ip;
  } catch (e) {
    console.error("IP fetch error:", e);
    return "unknown";
  }
}

/**
 * =====================================================
 *   Lấy Local IP (LAN)
 * =====================================================
 */
export function getLocalIP() {
  return new Promise((resolve) => {
    let ip = "unknown";
    const pc = new RTCPeerConnection({ iceServers: [] });

    pc.createDataChannel("");
    pc.createOffer().then((offer) => pc.setLocalDescription(offer));

    pc.onicecandidate = (event) => {
      if (!event || !event.candidate) {
        resolve(ip);
        return;
      }

      const regex = /([0-9]{1,3}(\.[0-9]{1,3}){3})/;
      const match = regex.exec(event.candidate.candidate);

      if (match) {
        ip = match[1];
        resolve(ip);
      }
    };
  });
}
