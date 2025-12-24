import React, { useState, useEffect } from "react";
import { login, getIP } from "../services/userService";
import { useNavigate } from "react-router-dom";
import { db } from "../firebase";
import { collection, addDoc, serverTimestamp, query, where, getDocs } from "firebase/firestore";
import sha256 from "crypto-js/sha256";
import emailjs from '@emailjs/browser';

// Inject keyframes
const styleSheet = document.createElement("style");
styleSheet.innerHTML = `
@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
@keyframes fadeInOut {
  0% { opacity: 0; transform: translateY(-20px);}
  10% { opacity: 1; transform: translateY(0);}
  90% { opacity: 1; transform: translateY(0);}
  100% { opacity: 0; transform: translateY(-20px);}
}
`;
document.head.appendChild(styleSheet);

const MAX_ATTEMPTS = 5;
const LOCK_TIME = 5 * 60 * 1000;

function getDeviceId() {
  const ua = navigator.userAgent || "";
  const platform = navigator.platform || "";
  const vendor = navigator.vendor || "";
  const raw = ua + platform + vendor;
  return sha256(raw).toString();
}

const LoginPage = () => {
  const nav = useNavigate();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [attempts, setAttempts] = useState(null);
  const [lockedUntil, setLockedUntil] = useState(0);
  const [lockCountdown, setLockCountdown] = useState("05:00");
  const [deviceId, setDeviceId] = useState("");
  const [showSuccess, setShowSuccess] = useState(false);
  const [showError, setShowError] = useState(false);

  useEffect(() => {
    document.body.style.overflow = "hidden";
    document.documentElement.style.overflow = "hidden";

    return () => {
      document.body.style.overflow = "auto";
      document.documentElement.style.overflow = "auto";
    };
  }, []);


  // Khởi tạo EmailJS
  useEffect(() => {
    emailjs.init("KGZrlh0QwPxu8oxhW");
  }, []);





// hàm check phiên
  useEffect(() => {
    const adminUser = JSON.parse(localStorage.getItem("adminUser"));
    if (!adminUser) return;

    const remaining = adminUser.expiresAt - Date.now();
    if (remaining <= 0) {
      localStorage.removeItem("adminUser");
      nav("/login");
      return;
    }

    const timer = setTimeout(() => {
      localStorage.removeItem("adminUser");
      nav("/login");
    }, remaining);

    return () => clearTimeout(timer);
  }, [nav]);



  //lấy id thiết bị
  useEffect(() => {
    setDeviceId(getDeviceId());
  }, []);





  useEffect(() => {
    if (!deviceId) return;
    const lockData = JSON.parse(localStorage.getItem("loginLock")) || {};
    const devData = lockData[deviceId] || { attempts: 0, lockedUntil: 0 };

    setAttempts(devData.attempts > 0 ? devData.attempts : "Vui lòng đăng nhập");
    if (devData.lockedUntil && Date.now() < devData.lockedUntil) {
      setLockedUntil(devData.lockedUntil);
    }
  }, [deviceId]);

  useEffect(() => {
    if (!lockedUntil || Date.now() >= lockedUntil) return;

    const interval = setInterval(() => {
      const remaining = lockedUntil - Date.now();
      if (remaining <= 0) {
        setLockedUntil(0);
        setAttempts("Vui lòng đăng nhập");
        setLockCountdown("00:00");
        clearInterval(interval);
      } else {
        const minutes = Math.floor(remaining / 60000);
        const seconds = Math.floor((remaining % 60000) / 1000);
        setLockCountdown(
          `${minutes.toString().padStart(2, "0")}:${seconds
            .toString()
            .padStart(2, "0")}`
        );
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [lockedUntil]);






const handleLogin = async (e) => {
  e.preventDefault();
  if (!deviceId) return;
  setLoading(true);

  const identifier = username.trim().toLowerCase();
  const pass = password.trim();

  const user = await login(identifier, pass);

  const lockData = JSON.parse(localStorage.getItem("loginLock")) || {};
  const devData = lockData[deviceId] || { attempts: 0, lockedUntil: 0 };

  if (lockedUntil && Date.now() < lockedUntil) {
    setLoading(false);
    return;
  }

  if (!user || user.role !== "admin") {
    setLoading(false);
    devData.attempts = (devData.attempts || 0) + 1;

    if (devData.attempts >= MAX_ATTEMPTS) {
      devData.lockedUntil = Date.now() + LOCK_TIME;
      devData.attempts = 0;
      setLockedUntil(devData.lockedUntil);
    }

    lockData[deviceId] = devData;
    localStorage.setItem("loginLock", JSON.stringify(lockData));
    setAttempts(devData.attempts > 0 ? devData.attempts : "Vui lòng đăng nhập");
    setShowError(true);
    setTimeout(() => setShowError(false), 2500);
    return;
  }

  lockData[deviceId] = { attempts: 0, lockedUntil: 0 };
  localStorage.setItem("loginLock", JSON.stringify(lockData));

  const ipPublic = await getIP();
  const userAgent = navigator.userAgent;
  const platform = navigator.platform || "unknown";
  const browserName = (() => {
    if (userAgent.includes("Chrome")) return "Chrome";
    if (userAgent.includes("Firefox")) return "Firefox";
    if (userAgent.includes("Safari") && !userAgent.includes("Chrome")) return "Safari";
    if (userAgent.includes("Edge")) return "Edge";
    return "Unknown Browser";
  })();


  let deviceType = "Desktop"; 
  let osName = "Unknown OS";

  // Kiểm tra Mobile
  if (/Mobile|Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(userAgent)) {
    deviceType = "Mobile";
  }

  // Xác định OS
  if (userAgent.includes("Windows")) osName = "Windows";
  else if (userAgent.includes("Macintosh") || userAgent.includes("Mac OS")) osName = "macOS";
  else if (userAgent.includes("Linux") && !userAgent.includes("Android")) osName = "Linux";
  else if (userAgent.includes("Android")) osName = "Android";
  else if (userAgent.includes("iPhone") || userAgent.includes("iPad") || userAgent.includes("iPod")) osName = "iOS";

  const deviceName = `${deviceType} - ${browserName} on ${osName}`;

  
  // === KIỂM TRA THIẾT BỊ MỚI TRƯỚC KHI LƯU LOG ===
  let isNewDevice = false;

  try {
    const logQuery = query(
      collection(db, "admin_web_logins"),
      where("adminId", "==", user.id)
    );
    const logSnap = await getDocs(logQuery);

    if (logSnap.empty) {
      isNewDevice = true;
      console.log("Lần đầu đăng nhập của user này → gửi email cảnh báo");
    } else {
      const hasSameDevice = logSnap.docs.some(doc => doc.data().deviceId === deviceId);
      isNewDevice = !hasSameDevice;
      console.log(hasSameDevice ? "Thiết bị quen thuộc → không gửi email" : "Thiết bị mới → gửi email cảnh báo");
    }
  } catch (err) {
    console.error("Lỗi kiểm tra log cũ:", err);
    isNewDevice = true; 
  }

  // Lưu log SAU khi kiểm tra
  try {
    await addDoc(collection(db, "admin_web_logins"), {
      adminId: user.id,
      username: user.username,
      ipPublic,
      deviceId,
      deviceName,        
      deviceType,       
      platform,
      userAgent,
      browserName,
      timestamp: serverTimestamp(),
      isRead: false,
    });
    console.log("Log đã lưu với tên thiết bị:", deviceName);
  } catch (err) {
    console.error("Lỗi lưu log:", err);
  }

  // Gửi email chỉ khi là thiết bị mới
if (isNewDevice) {
  try {
    const currentTime = new Date().toLocaleString("vi-VN");

    const templateParams = {
      fullname: user.fullname || user.username || "Người dùng",
      login_time: currentTime,
      ip: ipPublic || "Không xác định",
      browser: browserName,
      platform: platform,
      device: deviceName,
      to_email: user.email,                    
      to_name: user.fullname || user.username  
    };

    await emailjs.send(
      "KGZrlh0QwPxu8oxhW",
      "template_m9d6kue",
      templateParams
    );

    console.log("EMAIL CẢNH BÁO ĐÃ GỬI ĐẾN:", user.email);
  } catch (error) {
    console.error("LỖI GỬI EMAIL EMAILJS:", error);
  }
} else {
    console.log("Thiết bị quen thuộc → Không gửi email");
  }





  // Lưu =ss
  const expiresAt = Date.now() + 30 * 60 * 1000;
  const adminUser = {
    id: user.id,
    username: user.username,
    fullname: user.fullname,
    email: user.email,
    role: user.role,
    lastLogin: new Date().toISOString(),
    expiresAt,
  };
  localStorage.setItem("adminUser", JSON.stringify(adminUser));

  setShowSuccess(true);
  setTimeout(() => setShowSuccess(false), 2500);
  setTimeout(() => nav("/"), 1000);
};

  return (
    <div style={styles.container}>

      {/* Tiêu đề lớn */}
      <div style={styles.titleBox}>
        <h1 style={styles.mainTitle}>Trang quản trị hệ thống</h1>
        <p style={styles.subTitle}>
          Đăng nhập để truy cập vào bảng điều khiển quản lý
        </p>
      </div>

      <form style={styles.card} onSubmit={handleLogin}>
        <h2 style={{ color: "#000", marginBottom: 4, textAlign: "center"  }}>Đăng nhập</h2>
        <p style={{ fontSize: 13, color: "#555", marginTop: -5, textAlign: "center" }}>
          ⓘ Chỉ tài khoản quản trị viên mới có quyền truy cập
        </p>

        {showError && (
          <p style={{ color: "red", marginBottom: 8 }}>
            Tài khoản hoặc mật khẩu không chính xác
          </p>
        )}

        <input
          style={styles.input}
          placeholder="Email / Số điện thoại / Tên đăng nhập"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
        />
        <input
          type="password"
          style={styles.input}
          placeholder="Mật khẩu"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />


      {(attempts || (lockedUntil && Date.now() < lockedUntil)) && (
        <p
          style={{
            color: lockedUntil && Date.now() < lockedUntil ? "red" : "yellow",
            marginTop: 8,
          }}
        >
          {lockedUntil && Date.now() < lockedUntil
            ? `Vui lòng thử lại sau ${lockCountdown}`
            : attempts
            ? (typeof attempts === "number" ? `Bạn đã nhập sai mật khẩu ${attempts} lần` : attempts)
            : "Vui lòng đăng nhập"}
        </p>
      )}


        <button style={styles.button} disabled={loading}>
          {loading ? <span style={styles.spinner}></span> : "Đăng nhập"}
        </button>
      </form>

      {showSuccess && (
        <div style={styles.toast}>Đăng nhập thành công!</div>
      )}
    </div>
  );
};

export default LoginPage;


// ===================== CSS =====================
const styles = {


  
container: {
  minHeight: "100vh",
  width: "100%",
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  alignItems: "center",

  backgroundImage: "url('/bgad.png')",
  backgroundSize: "cover",       // ảnh lấp đầy màn hình, giữ tỉ lệ
  backgroundRepeat: "no-repeat",
  backgroundPosition: "center",
  backgroundColor: "#f0f0f0",    // nền trung tính phía sau ảnh
  backdropFilter: "blur(1px)",
  overflow: "hidden",
  padding: "20px",
  boxSizing: "border-box",
},



  titleBox: {
    textAlign: "center",
    marginBottom: 20,
  },

  mainTitle: {
    fontSize: 28,
    fontWeight: 700,
    color: "#000",
    marginBottom: 6,
  },

  subTitle: {
    fontSize: 14,
    color: "#333",
  },

  card: {
    width: "90%",
    maxWidth: 380,
    padding: 25,
    background: "#fff",
    borderRadius: 12,
    boxShadow: "0 4px 20px rgba(0,0,0,0.12)",
    display: "flex",
    flexDirection: "column",
    gap: 12,
  },

  input: {
    padding: "10px",
    borderRadius: 6,
    border: "1px solid #ccc",
  },

  button: {
    padding: "12px",
    background: "#2563eb",
    color: "#fff",
    border: "none",
    borderRadius: 6,
    cursor: "pointer",
    fontWeight: "600",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
  },

  spinner: {
    width: "16px",
    height: "16px",
    border: "2px solid rgba(255,255,255,0.6)",
    borderTopColor: "#fff",
    borderRadius: "50%",
    animation: "spin 0.8s linear infinite",
  },

  toast: {
    position: "fixed",
    top: 20,
    right: 20,
    background: "#4ade80",
    color: "#fff",
    padding: "12px 20px",
    borderRadius: 8,
    animation: "fadeInOut 2.5s ease forwards",
    fontWeight: 500,
    zIndex: 1000,
  },
};