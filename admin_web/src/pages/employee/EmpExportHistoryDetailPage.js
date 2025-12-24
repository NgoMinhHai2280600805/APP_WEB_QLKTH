// src/pages/employee/EmpExportHistoryDetailPage.js

import React, { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { db } from "../../firebase";
import { doc, getDoc } from "firebase/firestore";

const EmpExportHistoryDetailPage = () => {
  const { id } = useParams();
  const navigate = useNavigate();

  const [log, setLog] = useState(null);
  const [loading, setLoading] = useState(true);

  const formatDateTime = (timestamp) => {
    if (!timestamp || !timestamp.toDate) return "-";
    try {
      const date = timestamp.toDate();
      return date.toLocaleString("vi-VN", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch {
      return "-";
    }
  };

  const formatBatchDate = (dateField) => {
    if (!dateField) return "-";
    if (dateField.toDate) {
      return dateField.toDate().toLocaleDateString("vi-VN");
    }
    return "-";
  };

  useEffect(() => {
    const fetchLogDetail = async () => {
      if (!id) {
        alert("Không tìm thấy phiếu xuất");
        navigate("/employee/history");
        return;
      }

      setLoading(true);
      try {
        const docRef = doc(db, "staff_export_logs", id);
        const docSnap = await getDoc(docRef);

        if (!docSnap.exists()) {
          alert("Phiếu xuất kho không tồn tại");
          navigate("/employee/history");
          return;
        }

        setLog({ id: docSnap.id, ...docSnap.data() });
      } catch (err) {
        console.error("Lỗi tải chi tiết phiếu xuất:", err);
        alert("Không thể tải chi tiết phiếu xuất");
      } finally {
        setLoading(false);
      }
    };

    fetchLogDetail();
  }, [id, navigate]);

  if (loading) {
    return (
      <div style={{ padding: "40px", textAlign: "center", fontSize: "1.2em" }}>
        Đang tải chi tiết phiếu xuất...
      </div>
    );
  }

  if (!log) {
    return (
      <div style={{ padding: "40px", textAlign: "center", fontSize: "1.2em", color: "#888" }}>
        Không tìm thấy dữ liệu phiếu xuất
      </div>
    );
  }

  // Nhóm dữ liệu: danh mục → danh sách sản phẩm (mỗi sản phẩm có batches)
  const groupedByCategory = {};

  if (log.batches && Array.isArray(log.batches)) {
    log.batches.forEach((batchEntry) => {
      const batchNumber = batchEntry.batch_number || "Không có mã lô";
      batchEntry.products.forEach((prod) => {
        const catName = prod.category_name || "Không phân loại";
        const catId = prod.category_id || "uncategorized";
        const prodName = prod.product_name || "Không tên";
        const prodId = prod.product_id || "";

        if (!groupedByCategory[catId]) {
          groupedByCategory[catId] = {
            categoryName: catName,
            products: [],
          };
        }

        let productEntry = groupedByCategory[catId].products.find(p => p.productId === prodId);
        if (!productEntry) {
          productEntry = {
            productId: prodId,
            productName: prodName,
            batches: [],
          };
          groupedByCategory[catId].products.push(productEntry);
        }

        productEntry.batches.push({
          batchNumber,
          mfg_date: prod.mfg_date,
          exp_date: prod.exp_date,
          old_quantity: prod.old_quantity,
          export_quantity: prod.quantity,
          new_quantity: prod.new_quantity,
        });
      });
    });
  }

  return (
    <div style={{ padding: "20px", maxWidth: "1200px", margin: "0 auto" }}>
      <h2 style={{ textAlign: "center", marginBottom: "30px", color: "#2e7d32", fontSize: "1.8em" }}>
        CHI TIẾT PHIẾU XUẤT KHO
      </h2>

      {/* Thông tin chung phiếu */}
      <div
        style={{
          background: "#fff",
          padding: "20px",
          borderRadius: "12px",
          boxShadow: "0 4px 15px rgba(0,0,0,0.1)",
          marginBottom: "30px",
        }}
      >
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "20px" }}>
          <div>
            <strong>Mã phiếu xuất:</strong>{" "}
            <span style={{ fontSize: "1.3em", color: "#d32f2f", fontWeight: "bold" }}>
              {log.receipt_number || "N/A"}
            </span>
          </div>
          <div>
            <strong>Ngày xuất kho:</strong> {formatDateTime(log.exported_at)}
          </div>
          <div>
            <strong>Tổng số lượng xuất:</strong>{" "}
            <strong style={{ color: "#d32f2f", fontSize: "1.2em" }}>
              {log.total_export}
            </strong>{" "}
            sản phẩm
          </div>
        </div>
      </div>

      {/* Thông tin nhân viên */}
      <div
        style={{
          background: "#e8f5e8",
          padding: "20px",
          borderRadius: "12px",
          borderLeft: "5px solid #2e7d32",
          marginBottom: "40px",
        }}
      >
        <h3 style={{ margin: "0 0 15px 0", color: "#2e7d32" }}>Người thực hiện xuất kho</h3>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "12px" }}>
          <div><strong>Họ tên:</strong> {log.staff_name || "Nhân viên"}</div>
          <div><strong>Email:</strong> {log.staff_email || "-"}</div>
          <div><strong>Số điện thoại:</strong> {log.staff_phone || "-"}</div>
          <div><strong>Vai trò:</strong> {log.staff_role || "staff"}</div>
        </div>
      </div>

      <h3 style={{ margin: "30px 0 20px", color: "#2e7d32", fontSize: "1.4em" }}>
        Chi tiết sản phẩm đã xuất
      </h3>

      {Object.entries(groupedByCategory).length === 0 ? (
        <div style={{ textAlign: "center", padding: "40px", color: "#888", background: "#f9f9f9", borderRadius: "12px" }}>
          Không có dữ liệu sản phẩm xuất kho
        </div>
      ) : (
        Object.entries(groupedByCategory).map(([catId, catData]) => (
          <div
            key={catId}
            style={{
              marginBottom: "40px",
              background: "#f8fff8",
              borderRadius: "12px",
              border: "2px solid #a5d6a7",
              overflow: "hidden",
              boxShadow: "0 4px 12px rgba(0,0,0,0.08)",
            }}
          >
            {/* Tên danh mục */}
            <div
              style={{
                background: "#2e7d32",
                color: "white",
                padding: "16px 20px",
                fontSize: "1.3em",
                fontWeight: "bold",
              }}
            >
              {catData.categoryName.toUpperCase()}
            </div>

            {/* Bảng duy nhất cho toàn danh mục - rộng hơn */}
            <div style={{ padding: "20px" }}>
              <div style={{ overflowX: "auto" }}>
                <table
                  style={{
                    width: "100%",
                    borderCollapse: "collapse",
                    background: "#fff",
                    minWidth: "1000px", // ← Tăng độ rộng tối thiểu để trải đều
                  }}
                >
                  <thead>
                    <tr
                      style={{
                        background: "transparent",
                        borderBottom: "2px solid #ddd",
                      }}
                    >
                      <th style={{ ...thStyle, width: "6%" }}>STT</th>
                      <th style={{ ...thStyle, width: "28%", textAlign: "left" }}>Sản phẩm</th> {/* Rộng hơn cho tên SP dài */}
                      <th style={{ ...thStyle, width: "14%" }}>Mã lô</th>
                      <th style={{ ...thStyle, width: "12%" }}>Ngày SX</th>
                      <th style={{ ...thStyle, width: "12%" }}>Hạn SD</th>
                      <th style={{ ...thStyle, width: "10%" }}>Tồn trước</th>
                      <th style={{ ...thStyle, width: "10%" }}>SL xuất</th>
                      <th style={{ ...thStyle, width: "10%" }}>Còn lại</th>
                    </tr>
                  </thead>
                  <tbody>
                    {catData.products.map((prod, prodIndex) =>
                      prod.batches.map((batch, batchIdx) => {
                        const globalIndex = catData.products
                          .slice(0, prodIndex)
                          .reduce((sum, p) => sum + p.batches.length, 0) + batchIdx + 1;

                        return (
                          <tr
                            key={`${prod.productId}-${batchIdx}`}
                            style={{
                              backgroundColor: batchIdx % 2 === 0 ? "#f8fff8" : "#fff",
                            }}
                          >
                            <td style={tdStyle}>{globalIndex}</td>

                            {/* Tên sản phẩm - căn trái, chỉ hiện ở dòng đầu */}
                            <td style={{ ...tdStyle, textAlign: "left", fontWeight: batchIdx === 0 ? "bold" : "normal" }}>
                              {batchIdx === 0 ? prod.productName : ""}
                            </td>

                            <td style={tdStyle}>
                              <strong>{batch.batchNumber || "-"}</strong>
                            </td>
                            <td style={tdStyle}>{formatBatchDate(batch.mfg_date)}</td>
                            <td style={tdStyle}>{formatBatchDate(batch.exp_date)}</td>
                            <td style={tdStyle}>{batch.old_quantity}</td>
                            <td style={{ ...tdStyle, fontWeight: "bold", color: "#d32f2f" }}>
                              {batch.export_quantity}
                            </td>
                            <td style={{ ...tdStyle, fontWeight: "bold" }}>
                              {batch.new_quantity}
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        ))
      )}

      {/* Nút quay lại */}
      <div style={{ textAlign: "center", marginTop: "50px" }}>
        <button
          onClick={() => navigate("/employee/history")}
          style={{
            padding: "14px 36px",
            background: "#666",
            color: "white",
            border: "none",
            borderRadius: "10px",
            fontSize: "1.1em",
            fontWeight: "600",
            cursor: "pointer",
            boxShadow: "0 4px 10px rgba(0,0,0,0.15)",
          }}
        >
          ← Quay lại danh sách lịch sử
        </button>
      </div>
    </div>
  );
};

// Styles bảng - giữ nguyên nhưng thêm width cụ thể ở trên
const thStyle = {
  padding: "14px 12px",
  textAlign: "center",
  fontWeight: "700",
  fontSize: "1.02em",
  color: "#333",
};

const tdStyle = {
  padding: "14px 12px",
  textAlign: "center",
  borderBottom: "1px solid #eee",
};

export default EmpExportHistoryDetailPage;