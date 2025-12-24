import React, { useState, useEffect, useRef } from "react";
import { Link, Outlet, useLocation, useNavigate } from "react-router-dom";
import EmpHeader from "./EmpHeader";

const EmpDashboardPage = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const sidebarRef = useRef();

  const [isMobile, setIsMobile] = useState(window.innerWidth <= 768);
  const [sidebarOpen, setSidebarOpen] = useState(!isMobile);

  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth <= 768;
      setIsMobile(mobile);
      setSidebarOpen(!mobile);
    };
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // Điều hướng mặc định sang /employee/export
  useEffect(() => {
    if (location.pathname === "/employee") {
      navigate("export", { replace: true });
    }
  }, [location.pathname, navigate]);

  // Click outside => đóng sidebar
  useEffect(() => {
    if (!isMobile || !sidebarOpen) return;

    const handleClickOutside = (e) => {
      if (sidebarRef.current && !sidebarRef.current.contains(e.target)) {
        setSidebarOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [isMobile, sidebarOpen]);

  const toggleSidebar = () => setSidebarOpen(!sidebarOpen);

  const isActive = (path) => location.pathname.includes(path);

  const menuItemStyle = (active) => ({
    padding: isMobile ? "6px 10px" : "10px 14px",
    margin: "8px 0",
    borderRadius: "8px",
    textDecoration: "none",
    display: "block",
    fontWeight: active ? "600" : "500",
    backgroundColor: active ? "#e0f2fe" : "transparent",
    color: active ? "#0369a1" : "#374151",
    border: active ? "1px solid #bae6fd" : "1px solid transparent",
    fontSize: isMobile ? "0.85em" : "1em",
    transition: "0.2s",
  });

  return (
    <div
      style={{
        height: "100vh",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
      }}
    >
      {/* HEADER */}
      <div style={{ flexShrink: 0 }}>
        <EmpHeader toggleSidebar={toggleSidebar} />
      </div>

      <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
        {/* SIDEBAR */}
        {sidebarOpen && (
          <nav
            ref={sidebarRef}
            style={{
              width: isMobile ? "200px" : "180px",
              position: isMobile ? "fixed" : "relative",
              top: 0,
              left: 0,
              height: "100%",
              background: "#fff",
              borderRight: "1px solid #e5e7eb",
              zIndex: 1000,
              padding: "20px 15px",
              boxShadow: isMobile ? "2px 0 8px rgba(0,0,0,0.2)" : "none",
              transition: "transform 0.3s ease",
              transform: isMobile ? "translateX(0)" : "none",
            }}
          >
            <ul style={{ listStyle: "none", padding: 0 }}>
              <li>
                <Link
                  to="export"
                  style={menuItemStyle(isActive("/employee/export"))}
                >
                  Xuất hàng
                </Link>
              </li>

              <li>
                <Link
                  to="history"
                  style={menuItemStyle(isActive("/employee/history"))}
                >
                  Lịch sử xuất hàng
                </Link>
              </li>
            </ul>
          </nav>
        )}

        {/* OVERLAY (mobile) */}
        {isMobile && sidebarOpen && (
          <div
            onClick={() => setSidebarOpen(false)}
            style={{
              position: "fixed",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
              backgroundColor: "rgba(0,0,0,0.3)",
              zIndex: 500,
            }}
          />
        )}

        {/* MAIN CONTENT */}
        <main
          style={{
            flex: 1,
            overflowY: "auto",
            padding: isMobile ? "5px" : "25px",
            background: "#eef2f7",
          }}
        >
          <div
            style={{
              background: "#fff",
              padding: isMobile ? "15px" : "25px",
              borderRadius: "12px",
              boxShadow: "0 2px 10px rgba(0,0,0,0.05)",
              minHeight: "calc(100%)",
            }}
          >
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
};

export default EmpDashboardPage;
