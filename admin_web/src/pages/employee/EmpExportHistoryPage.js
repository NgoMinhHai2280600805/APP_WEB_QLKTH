// src/pages/employee/EmpExportHistoryPage.js

import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { db } from "../../firebase";
import {
  collection,
  query,
  orderBy,
  getDocs,
  limit,
} from "firebase/firestore";
import { format } from "date-fns";  // Giữ nguyên, sau khi cài package sẽ ok

const EmpExportHistoryPage = () => {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  const navigate = useNavigate();

  // Format timestamp Firestore thành ngày giờ đẹp
  const formatDate = (timestamp) => {
    if (!timestamp) return "-";
    try {
      return format(timestamp.toDate(), "dd/MM/yyyy HH:mm");
    } catch {
      return "-";
    }
  };

  // Lấy danh sách phiếu xuất kho
  useEffect(() => {
    const fetchLogs = async () => {
      setLoading(true);
      try {
        const q = query(
          collection(db, "staff_export_logs"),
          orderBy("exported_at", "desc"),
          limit(50)  // Giới hạn 50 bản ghi mới nhất
        );

        const snap = await getDocs(q);
        if (snap.empty) {
          setLogs([]);
          setLoading(false);
          return;
        }

        const data = [];
        snap.forEach((docSnap) => {
          const item = { id: docSnap.id, ...docSnap.data() };
          data.push(item);
        });

        setLogs(data);
      } catch (err) {
        console.error("Lỗi tải lịch sử xuất kho:", err);
        alert("Không thể tải lịch sử xuất kho");
      } finally {
        setLoading(false);
      }
    };

    fetchLogs();
  }, []);

  const handleRowClick = (logId) => {
    navigate(`/employee/history/${logId}`);
  };

  return (
    <div style={{ padding: "20px", maxWidth: "1200px", margin: "0 auto" }}>
      <h2 style={{ textAlign: "center", marginBottom: "30px", color: "#2e7d32" }}>
        LỊCH SỬ XUẤT KHO
      </h2>

      {loading ? (
        <p style={{ textAlign: "center", fontSize: "1.2em", color: "#555" }}>
          Đang tải lịch sử...
        </p>
      ) : logs.length === 0 ? (
        <p style={{ textAlign: "center", fontSize: "1.2em", color: "#888" }}>
          Chưa có phiếu xuất kho nào
        </p>
      ) : (
        <div style={{ overflowX: "auto", borderRadius: "12px", boxShadow: "0 4px 15px rgba(0,0,0,0.1)" }}>
          <table
            style={{
              width: "100%",
              borderCollapse: "collapse",
              background: "#fff",
              minWidth: "800px",
            }}
          >
            <thead>
              <tr style={{ background: "#2e7d32", color: "white" }}>
                <th style={thStyle}>Mã phiếu</th>
                <th style={thStyle}>Ngày xuất</th>
                <th style={thStyle}>Sản phẩm</th>
                <th style={thStyle}>Tổng SL xuất</th>
                <th style={thStyle}>Người xuất</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log, index) => (
                <tr
                  key={log.id}
                  onClick={() => handleRowClick(log.id)}
                  style={{
                    backgroundColor: index % 2 === 0 ? "#f8fff8" : "#fff",
                    cursor: "pointer",
                    transition: "0.2s",
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = "#e0f7fa")}
                  onMouseLeave={(e) =>
                    (e.currentTarget.style.backgroundColor = index % 2 === 0 ? "#f8fff8" : "#fff")
                  }
                >
                  <td style={tdStyle}>
                    <strong>{log.receipt_number || "N/A"}</strong>
                  </td>
                  <td style={tdStyle}>{formatDate(log.exported_at)}</td>
                  <td style={tdStyle}>
                    <div>
                      <div style={{ fontWeight: "600" }}>{log.product_name}</div>
                      <div style={{ fontSize: "0.9em", color: "#666" }}>
                        {log.category_name || "Không phân loại"}
                      </div>
                    </div>
                  </td>
                  <td style={tdStyle} className="text-center">
                    <strong style={{ color: "#d32f2f" }}>{log.total_export}</strong>
                  </td>
                  <td style={tdStyle}>
                    <div>
                      <div>{log.staff_name || "Nhân viên"}</div>
                      <div style={{ fontSize: "0.9em", color: "#666" }}>{log.staff_email}</div>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

// Styles tái sử dụng
const thStyle = {
  padding: "16px 12px",
  textAlign: "left",
  fontWeight: "600",
  fontSize: "1.05em",
};

const tdStyle = {
  padding: "16px 12px",
  borderBottom: "1px solid #eee",
  verticalAlign: "top",
};

export default EmpExportHistoryPage;