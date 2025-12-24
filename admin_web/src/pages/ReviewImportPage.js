import React, { useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { importExcelData } from "../services/importService";

const FIELDS = [
  { key: "batch_number", label: "Mã lô" },
  { key: "category_name", label: "Danh mục" },
  { key: "product_name", label: "Tên sản phẩm" },
  { key: "quantity", label: "Số lượng" },
  { key: "price", label: "Giá" },
  { key: "mfg_date", label: "Ngày sản xuất" },
  { key: "exp_date", label: "Hạn sử dụng" },
  { key: "supplier_name", label: "Nhà cung cấp" },
  { key: "receipt_number", label: "Mã phiếu nhập" },
  { key: "category_description", label: "Mô tả danh mục" },
  { key: "product_description", label: "Mô tả sản phẩm" },
];

/* ------------------------------------------
   HÀM FORMAT HIỂN THỊ (chỉ dùng cho UI review)
------------------------------------------- */
const formatDisplayValue = (value, key) => {
  if (value === null || value === undefined || value === "") return "";

  // Ngày tháng: nếu là Date object hoặc string hợp lệ → format DD/MM/YYYY
  if (key === "mfg_date" || key === "exp_date") {
    let date;
    if (value instanceof Date) {
      date = value;
    } else if (typeof value === "string") {
      date = new Date(value.replace(/-/g, "/")); // hỗ trợ cả YYYY-MM-DD
    }

    if (date && !isNaN(date.getTime())) {
      return date.toLocaleDateString("vi-VN"); // → 15/03/2025
    }
    return value; // nếu không parse được, giữ nguyên
  }

  // Số lượng: thêm dấu chấm phân cách hàng nghìn
  if (key === "quantity" && typeof value === "number") {
    return value.toLocaleString("vi-VN");
  }

  // Giá tiền: thêm dấu chấm + chữ "đ"
  if (key === "price" && typeof value === "number") {
    return `${value.toLocaleString("vi-VN")} đ`;
  }

  return value;
};

export default function ReviewImportPage() {
  const { state } = useLocation();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);

  if (!state || !state.filesData) {
    return (
      <div style={{ padding: 20 }}>
        <h3>Không có dữ liệu để xem lại!</h3>
        <button onClick={() => navigate(-1)}>Quay về</button>
      </div>
    );
  }

  const filesData = state.filesData;

  const handleImport = async () => {
    setLoading(true);
    try {
      const adminUser = JSON.parse(localStorage.getItem("adminUser") || "null");

      if (!adminUser || !adminUser.username) {
        alert("Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại!");
        navigate("/login", { replace: true });
        return;
      }

      const adminInfo = {
        name: adminUser.fullname || "",
        email: adminUser.email || "",
        role: adminUser.role || "",
        username: adminUser.username || "",
        phone: adminUser.phone || "",
      };

      for (const f of filesData) {
        const rows = f.rows.map((r) => {
          const obj = {};
          FIELDS.forEach((field) => {
            const col = f.mapping[field.key];
            obj[field.key] = col ? r[col] ?? null : null;
          });
          return obj;
        });

        await importExcelData(rows, adminInfo);
      }

      alert("NHẬP HÀNG THÀNH CÔNG!");

      localStorage.removeItem("importFilesData");
      navigate("/import", { replace: true });
    } catch (err) {
      console.error(err);
      alert("Lỗi khi import!");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ marginBottom: 20 }}>Thông tin nhập hàng</h2>

      {filesData.map((file) => (
        <div key={file.id} style={{ marginBottom: 30 }}>
          <h3 style={{ marginBottom: 10 }}>
            {file.file?.name || file.fileName || "(không có tên file)"}
          </h3>

          <div
            style={{
              maxHeight: 600,
              overflowY: "auto",
              overflowX: "auto",
              border: "1px solid #ccc",
              borderRadius: 6,
            }}
          >
            <table style={{ borderCollapse: "collapse", minWidth: "100%" }}>
              <thead>
                <tr>
                  {FIELDS.map((f) => (
                    <th
                      key={f.key}
                      style={{
                        padding: "10px 12px",
                        borderBottom: "2px solid #bbb",
                        backgroundColor: "#f0f4f8",
                        textAlign: "left",
                        position: "sticky",
                        top: 0,
                        zIndex: 1,
                      }}
                    >
                      {f.label}
                    </th>
                  ))}
                </tr>
              </thead>

              <tbody>
                {file.rows.map((r, idx) => (
                  <tr
                    key={r.__rowId}
                    style={{
                      backgroundColor: idx % 2 === 0 ? "#ffffff" : "#f9fafb",
                      transition: "background 0.2s",
                    }}
                  >
                    {FIELDS.map((f) => {
                      const rawValue = file.mapping[f.key] ? r[file.mapping[f.key]] : "";
                      const displayValue = formatDisplayValue(rawValue, f.key);

                      return (
                        <td
                          key={`${r.__rowId}-${f.key}`}
                          style={{
                            padding: "8px 12px",
                            borderBottom: "1px solid #ddd",
                          }}
                        >
                          {displayValue}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ))}

      <div style={{ display: "flex", gap: 10, marginTop: 20 }}>
        <button
          onClick={() => navigate(-1)}
          style={{
            padding: "10px 20px",
            background: "#6c757d",
            color: "white",
            border: "none",
            borderRadius: 5,
            cursor: "pointer",
            fontWeight: 500,
          }}
        >
          Quay lại chỉnh sửa
        </button>

        <button
          onClick={handleImport}
          disabled={loading}
          style={{
            position: "relative",
            padding: "10px 20px",
            background: "green",
            color: "white",
            border: "none",
            borderRadius: 5,
            cursor: loading ? "not-allowed" : "pointer",
            fontWeight: 500,
            display: "flex",
            alignItems: "center",
            gap: 8,
          }}
        >
          {loading && (
            <div
              style={{
                border: "2px solid #fff",
                borderTop: "2px solid transparent",
                borderRadius: "50%",
                width: 16,
                height: 16,
                animation: "spin 1s linear infinite",
              }}
            />
          )}
          {loading ? "Đang nhập hàng..." : "Xác nhận nhập hàng"}
        </button>
      </div>

      <style jsx>{`
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}