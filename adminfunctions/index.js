const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// === CẤU HÌNH GMAIL SMTP ===
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "longphimon003@gmail.com",          // ← THAY BẰNG EMAIL GMAIL THẬT CỦA BẠN (ví dụ: abc@gmail.com)
    pass: "cgnpcdorjqotqehp",               // ← App Password bạn đã có (không khoảng trắng)
  },
});

// === FUNCTION GỬI CẢNH BÁO ĐĂNG NHẬP THIẾT BỊ MỚI CHO ADMIN ===
exports.sendAdminLoginAlert = functions.https.onCall(async (data, context) => {
  const {
    adminId,
    email,
    fullname,
    ipPublic,
    deviceId,
    browserName,
    platform,
    timestamp,
  } = data;

  if (!email) {
    return { success: false, message: "Không có email người nhận" };
  }

  // Kiểm tra xem thiết bị đã từng đăng nhập chưa
  const logRef = admin.firestore().collection("admin_web_logins");
  const snapshot = await logRef
    .where("adminId", "==", adminId)
    .where("deviceId", "==", deviceId)
    .limit(1)
    .get();

  // Nếu đã từng đăng nhập → không gửi email
  if (!snapshot.empty) {
    return { success: true, isNewDevice: false };
  }

  // Gửi email cảnh báo
  const mailOptions = {
    from: `"Hệ thống Quản lý Kho" <qlkho.nhom8@gmail.com>`,  // ← Thay cùng email ở trên
    to: email,
    subject: "🚨 Cảnh báo: Đăng nhập từ thiết bị mới",
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px; background: #f9f9f9; border-radius: 8px;">
        <h2 style="color: #d32f2f;">Cảnh báo bảo mật tài khoản Admin</h2>
        <p>Xin chào <strong>${fullname || "Quản trị viên"}</strong>,</p>
        <p>Hệ thống phát hiện <strong>đăng nhập từ thiết bị mới</strong> vào tài khoản admin của bạn:</p>
        <ul>
          <li><strong>Thời gian:</strong> ${new Date(timestamp).toLocaleString("vi-VN")}</li>
          <li><strong>IP công khai:</strong> ${ipPublic || "Không xác định"}</li>
          <li><strong>Trình duyệt:</strong> ${browserName}</li>
          <li><strong>Nền tảng:</strong> ${platform}</li>
        </ul>
        <p style="color: #d32f2f; font-weight: bold;">
          Nếu không phải bạn, vui lòng đổi mật khẩu ngay lập tức và kiểm tra tài khoản!
        </p>
        <hr>
        <small>Hệ thống quản lý kho hàng - NHÓM 8</small>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log("Email cảnh báo đã gửi đến:", email);
    return { success: true, isNewDevice: true };
  } catch (error) {
    console.error("Lỗi gửi email:", error);
    return { success: false, message: error.toString() };
  }
});