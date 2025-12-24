import React, { useState, useEffect } from "react";
import { employeeLogin, getIP } from "../../services/employeeAuthService";
import { useNavigate } from "react-router-dom";
import { db } from "../../firebase";
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
  const raw =
    (navigator.userAgent || "") +
    (navigator.platform || "") +
    (navigator.vendor || "");
  return sha256(raw).toString();
}

const EmpLoginPage = () => {
  const nav = useNavigate();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const [showTopError, setShowTopError] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  const [attempts, setAttempts] = useState("Vui lòng đăng nhập");
  const [deviceId, setDeviceId] = useState("");
  const [lockedUntil, setLockedUntil] = useState(0);
  const [countdown, setCountdown] = useState("05:00");

  // Load device ID
  useEffect(() => {
    setDeviceId(getDeviceId());
  }, []);

  // Load lock data
  useEffect(() => {
    if (!deviceId) return;

    const lockData = JSON.parse(localStorage.getItem("empLoginLock")) || {};
    const dev = lockData[deviceId] || { attempts: 0, lockedUntil: 0 };

    setAttempts(dev.attempts || "Vui lòng đăng nhập");

    if (dev.lockedUntil && Date.now() < dev.lockedUntil) {
      setLockedUntil(dev.lockedUntil);
    }
  }, [deviceId]);

  // Countdown
  useEffect(() => {
    if (!lockedUntil || Date.now() >= lockedUntil) return;

    const timer = setInterval(() => {
      const remain = lockedUntil - Date.now();
      if (remain <= 0) {
        setLockedUntil(0);
        setAttempts("Vui lòng đăng nhập");
        clearInterval(timer);
      } else {
        const m = Math.floor(remain / 60000);
        const s = Math.floor((remain % 60000) / 1000);
        setCountdown(
          `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
        );
      }
    }, 1000);

    return () => clearInterval(timer);
  }, [lockedUntil]);

  // Init EmailJS
  useEffect(() => {
    emailjs.init("KGZrlh0QwPxu8oxhW");
  }, []);






  
  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);

    const lockData = JSON.parse(localStorage.getItem("empLoginLock")) || {};
    const dev = lockData[deviceId] || { attempts: 0, lockedUntil: 0 };

    if (lockedUntil && Date.now() < lockedUntil) {
      setLoading(false);
      return;
    }

    const user = await employeeLogin(identifier.trim(), password.trim());

    // Sai tài khoản / mật khẩu
    if (!user || user.role !== "staff") {
      setLoading(false);
      dev.attempts = (dev.attempts || 0) + 1;

      if (dev.attempts >= MAX_ATTEMPTS) {
        dev.lockedUntil = Date.now() + LOCK_TIME;
        dev.attempts = 0;
        setLockedUntil(dev.lockedUntil);
      }

      lockData[deviceId] = dev;
      localStorage.setItem("empLoginLock", JSON.stringify(lockData));
      setAttempts(dev.attempts);

      setShowTopError(true);
      setTimeout(() => setShowTopError(false), 2500);
      return;
    }

    // Bị khóa bởi admin
    if (user.is_locked) {
      setShowTopError(true);
      setTimeout(() => setShowTopError(false), 2500);
      setLoading(false);
      return;
    }

    // Reset attempts
    lockData[deviceId] = { attempts: 0, lockedUntil: 0 };
    localStorage.setItem("empLoginLock", JSON.stringify(lockData));

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

    // Tạo tên thiết bị chi tiết + phân biệt Desktop/Mobile
    let deviceType = "Desktop";
    let osName = "Unknown OS";

    if (/Mobile|Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(userAgent)) {
      deviceType = "Mobile";
    }

    if (userAgent.includes("Windows")) osName = "Windows";
    else if (userAgent.includes("Macintosh") || userAgent.includes("Mac OS")) osName = "macOS";
    else if (userAgent.includes("Linux") && !userAgent.includes("Android")) osName = "Linux";
    else if (userAgent.includes("Android")) osName = "Android";
    else if (userAgent.includes("iPhone") || userAgent.includes("iPad") || userAgent.includes("iPod")) osName = "iOS";

    const deviceName = `${deviceType} - ${browserName} on ${osName}`;

    // Kiểm tra thiết bị mới trước khi lưu log
    let isNewDevice = false;

    try {
      const logQuery = query(
        collection(db, "staff_web_logins"),
        where("staffId", "==", user.id)
      );
      const logSnap = await getDocs(logQuery);

      if (logSnap.empty) {
        isNewDevice = true;
      } else {
        const hasSameDevice = logSnap.docs.some(doc => doc.data().deviceId === deviceId);
        isNewDevice = !hasSameDevice;
      }
    } catch (err) {
      console.error("Lỗi kiểm tra log cũ (staff):", err);
      isNewDevice = true;
    }

    // Lưu log vào Firestore
    try {
      await addDoc(collection(db, "staff_web_logins"), {
        staffId: user.id,
        username: user.username,
        role: "staff",
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
      console.log("Log staff đã lưu:", deviceName);
    } catch (err) {
      console.error("Lỗi lưu log staff:", err);
    }

    // Gửi email cảnh báo nếu là thiết bị mới
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
      to_email: user.email,                    // ← Gửi đến email của user đăng nhập
      to_name: user.fullname || user.username  // ← Tên người nhận (dùng {{to_name}} nếu muốn)
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
      console.log("Staff đăng nhập từ thiết bị quen thuộc → Không gửi email");
    }

    // Lưu session employee
    const expiresAt = Date.now() + 60 * 60 * 1000; // 1 giờ
    localStorage.setItem(
      "employeeUser",
      JSON.stringify({
        id: user.id,
        username: user.username || "",
        fullname: user.fullname || "",
        email: user.email || "",
        phone: user.phone || "",
        avatar: user.avatar || "",
        role: "staff",
        expiresAt,
      })
    );

    // Hiển thị TOAST thành công
    setShowSuccess(true);
    setTimeout(() => setShowSuccess(false), 2500);

    setTimeout(() => nav("/employee"), 800);
  };

  return (
    <div style={styles.container}>
      {/* --- TIÊU ĐỀ TRANG --- */}
      <div style={styles.headerWrapper}>
        <h1 style={styles.mainTitle}>
          Chào mừng bạn đến với trang web xuất hàng của nhân viên
        </h1>
        <p style={styles.subText}>
          Hệ thống hỗ trợ quản lý - theo dõi - xuất kho dành cho nhân viên kho.
        </p>
      </div>

      {/* --- FORM LOGIN --- */}
      <form style={styles.card} onSubmit={handleLogin}>
        <h2 style={styles.title}>Đăng nhập</h2>

        {showTopError && (
          <p style={{ color: "red", textAlign: "left", marginBottom: 5 }}>
            Tài khoản hoặc mật khẩu không chính xác
          </p>
        )}

        <input
          style={styles.input}
          placeholder="Email / SDT / Username"
          value={identifier}
          onChange={(e) => setIdentifier(e.target.value)}
          disabled={lockedUntil && Date.now() < lockedUntil}
        />

        <input
          style={styles.input}
          type="password"
          placeholder="Mật khẩu"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={lockedUntil && Date.now() < lockedUntil}
        />

        {(attempts || lockedUntil) && (
          <p
            style={{
              color:
                lockedUntil && Date.now() < lockedUntil ? "red" : "orange",
              textAlign: "left",
              marginTop: 5,
              marginBottom: 5,
            }}
          >
            {lockedUntil && Date.now() < lockedUntil
              ? `Vui lòng thử lại sau ${countdown}`
              : typeof attempts === "number"
              ? `Bạn đã nhập sai ${attempts} lần`
              : attempts}
          </p>
        )}

        <button
          style={styles.button}
          disabled={loading || (lockedUntil && Date.now() < lockedUntil)}
        >
          {loading ? <span style={styles.spinner}></span> : "Đăng nhập"}
        </button>
      </form>

      {/* TOAST */}
      {showSuccess && (
        <div style={styles.toastSuccess}>Đăng nhập thành công!</div>
      )}
    </div>
  );
};

export default EmpLoginPage;

// ======================== CSS ========================
const styles = {
  headerWrapper: {
    position: "absolute",
    top: 60,
    textAlign: "center",
    zIndex: 9999,
  },

  mainTitle: {
    fontSize: 26,
    fontWeight: 700,
    color: "#ca61ffff ",
    marginBottom: 8,
  },
  subText: {
    fontSize: 14,
    color: "#d176ffff",
    marginBottom: 18,
  },

  logoCircle: {
    width: 60,
    height: 60,
    borderRadius: "50%",
    background: "#fff",
    boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: 30,
    margin: "0 auto",
    marginBottom: 20,
  },

  container: {
    height: "100vh",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",

    /* Ảnh nền từ public/bg.jpg */
    backgroundImage: "url('/bg.png')",
    backgroundSize: "cover",
    backgroundPosition: "center",
    backgroundRepeat: "no-repeat",

    /* Lớp phủ mờ nhẹ cho dễ nhìn nội dung */
    backdropFilter: "blur(1px)",
  },

  card: {
    width: 350,
    padding: 25,
    background: "#fff",
    borderRadius: 12,
    boxShadow: "0 4px 20px rgba(0,0,0,0.1)",
    display: "flex",
    flexDirection: "column",
    gap: 12,
  },
  title: {
    textAlign: "center",
    marginBottom: 10,
  },
  input: {
    padding: 10,
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
    transition: "0.2s",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
  },
  spinner: {
    width: "16px",
    height: "16px",
    border: "2px solid rgba(255,255,255,0.6)",
    borderTopColor: "#fff",
    borderRadius: "50%",
    animation: "spin 0.8s linear infinite",
  },
  toastSuccess: {
    position: "fixed",
    top: 20,
    right: 20,
    background: "#ffffff",
    color: "#333",
    padding: "12px 20px",
    borderRadius: 8,
    boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
    animation: "fadeInOut 2.5s ease forwards",
    fontWeight: 500,
    zIndex: 999,
    border: "1px solid #ddd",
  },
};