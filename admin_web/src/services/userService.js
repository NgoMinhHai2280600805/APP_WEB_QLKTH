import { collection, query, where, getDocs } from "firebase/firestore";
import { db } from "../firebase"; 
import sha256 from "crypto-js/sha256";
export async function login(identifier, password) {
  try {
    const hashed = sha256(password).toString();

    let q;

    // Nếu identifier chứa @ thì coi là email
    if (identifier.includes("@")) {
      q = query(
        collection(db, "users"),
        where("email", "==", identifier),
        where("password", "==", hashed)
      );
    }
    // Nếu là chỉ số => coi là phone
    else if (/^[0-9]+$/.test(identifier)) {
      q = query(
        collection(db, "users"),
        where("phone", "==", identifier),
        where("password", "==", hashed)
      );
    }
    // Mặc định là username
    else {
      q = query(
        collection(db, "users"),
        where("username", "==", identifier),
        where("password", "==", hashed)
      );
    }

    const snap = await getDocs(q);
    if (snap.empty) return null;

    const doc = snap.docs[0];
    return { id: doc.id, ...doc.data() };
  } catch (e) {
    console.error("Login error:", e);
    return null;
  }
}


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

export function getLocalIP() {
  return new Promise((resolve) => {
    let ip = "unknown";
    const pc = new RTCPeerConnection({ iceServers: [] });

    pc.createDataChannel("");
    pc.createOffer().then(offer => pc.setLocalDescription(offer));

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

