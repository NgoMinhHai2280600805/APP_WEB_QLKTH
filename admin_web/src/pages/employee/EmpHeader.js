import React from "react";

const EmpHeader = ({ toggleSidebar }) => {
  const user = JSON.parse(localStorage.getItem("employeeUser") || "{}");

  function logout() {
    localStorage.removeItem("employeeUser");
    window.location.href = "/employee/login";
  }

  return (
    <header style={styles.header}>
      {/* Nút 3 gạch */}
      <button style={styles.menuBtn} onClick={toggleSidebar}>
        ☰
      </button>

      <h3 style={styles.title}>Hệ thống nhân viên</h3>

      <div style={styles.userBox}>
        <span style={styles.username}>{user.fullname}</span>
        <button style={styles.logoutBtn} onClick={logout}>
          Đăng xuất
        </button>
      </div>
    </header>
  );
};

export default EmpHeader;

const styles = {
  header: {
    width: "100%",
    position: "sticky",
    top: 0,
    zIndex: 50,
    background: "#ffffff",
    padding: "12px 25px",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    borderBottom: "1px solid #e5e7eb",
    boxShadow: "0 2px 8px rgba(0,0,0,0.05)",
    boxSizing: "border-box",
    flexWrap: "wrap",
  },
  menuBtn: {
    fontSize: "22px",
    background: "transparent",
    border: "none",
    cursor: "pointer",
    marginRight: 15,
    flexShrink: 0,
  },
  title: {
    margin: 0,
    fontWeight: 700,
    flex: 1,
    minWidth: 0,
  },
  userBox: {
    display: "flex",
    alignItems: "center",
    gap: 15,
    flexShrink: 0,
    maxWidth: "50%",
    overflow: "hidden",
    textOverflow: "ellipsis",
  },
  username: {
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis",
  },
  logoutBtn: {
    background: "#dc2626",
    color: "#fff",
    border: "none",
    padding: "6px 12px",
    borderRadius: 6,
    cursor: "pointer",
    fontWeight: 600,
    flexShrink: 0,
  },
};
