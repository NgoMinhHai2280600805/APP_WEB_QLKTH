import React from "react";
import { Navigate } from "react-router-dom";

const ProtectedRoute = ({ children }) => {
  const raw = localStorage.getItem("adminUser");

  if (!raw) return <Navigate to="/login" replace />;

  let user = null;
  try {
    user = JSON.parse(raw);
  } catch {
    localStorage.removeItem("adminUser");
    return <Navigate to="/login" replace />;
  }

  // Kiểm tra hết hạn login
  const now = Date.now();
  if (!user.expiresAt || now > user.expiresAt) {
    localStorage.removeItem("adminUser");
    return <Navigate to="/login" replace />;
  }

  return children;
};

export default ProtectedRoute;
