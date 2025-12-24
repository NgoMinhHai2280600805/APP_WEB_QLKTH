import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";

import LoginPage from "./pages/LoginPage";
import DashboardPage from "./pages/DashboardPage";
import ReviewImportPage from "./pages/ReviewImportPage";
import ImportExcelPage from "./pages/ImportExcelPage";
import ImportHistoryPage from "./pages/ImportHistoryPage";
import ImportHistoryDetailPage from "./pages/ImportHistoryDetailPage";

// Component bảo vệ route (chỉ admin mới vào được)
import ProtectedRoute from "./components/ProtectedRoute";

// ========== EMPLOYEE ROUTES ==========
import EmpLoginPage from "./pages/employee/EmpLoginPage";
import EmpDashboardPage from "./pages/employee/EmpDashboardPage";
import EmpExportPage from "./pages/employee/EmpExportPage";
import EmpExportHistoryPage from "./pages/employee/EmpExportHistoryPage";
import EmpProtectedRoute from "./pages/employee/EmpProtectedRoute";
import EmpExportHistoryDetailPage from "./pages/employee/EmpExportHistoryDetailPage";


export default function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>

        {/* ========== LOGIN ADMIN ========== */}
        <Route path="/login" element={<LoginPage />} />

        {/* ========== DASHBOARD ADMIN (protected) ========== */}
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <DashboardPage />
            </ProtectedRoute>
          }
        >
          <Route index element={<ImportExcelPage />} />
          <Route path="import" element={<ImportExcelPage />} />
          <Route path="history" element={<ImportHistoryPage />} />
          <Route path="history/:id" element={<ImportHistoryDetailPage />} />
          <Route path="review-import" element={<ReviewImportPage />} />
        </Route>

        {/* ========================================================= */}
        {/* ========== EMPLOYEE LOGIN ========== */}
        {/* ========================================================= */}
        <Route path="/employee/login" element={<EmpLoginPage />} />

        {/* ========== EMPLOYEE DASHBOARD (protected) ========== */}
        <Route
          path="/employee"
          element={
            <EmpProtectedRoute>
              <EmpDashboardPage />
            </EmpProtectedRoute>
          }
        >
          <Route path="export" element={<EmpExportPage />} />
          <Route path="history" element={<EmpExportHistoryPage />} />
          <Route path="history/:id" element={<EmpExportHistoryDetailPage />} />
        </Route>

        {/* ========== FALLBACK ========== */}
        <Route path="*" element={<LoginPage />} />

      </Routes>
    </BrowserRouter>
  );
}
