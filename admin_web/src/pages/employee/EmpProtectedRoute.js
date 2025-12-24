import React from "react";
import { Navigate } from "react-router-dom";

const EmpProtectedRoute = ({ children }) => {
  const raw = localStorage.getItem("employeeUser");
  if (!raw) return <Navigate to="/employee/login" replace />;

  let user;
  try {
    user = JSON.parse(raw);
  } catch {
    localStorage.removeItem("employeeUser");
    return <Navigate to="/employee/login" replace />;
  }

  if (!user.expiresAt || Date.now() > user.expiresAt) {
    localStorage.removeItem("employeeUser");
    return <Navigate to="/employee/login" replace />;
  }

  return children;
};

export default EmpProtectedRoute;
