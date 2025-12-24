import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { db } from "../firebase";
import { doc, getDoc } from "firebase/firestore";


const FIELDS = [
  { key: "batch_number", label: "Mã lô" },
  { key: "supplier_name", label: "Nhà cung cấp" },
  { key: "category_name", label: "Danh mục" },
  { key: "category_description", label: "Mô tả danh mục" },
  { key: "product_name", label: "Tên sản phẩm" },
  { key: "product_description", label: "Mô tả sản phẩm" },
  { key: "price", label: "Giá" },
  { key: "quantity", label: "Số lượng" },
  { key: "mfg_date", label: "Ngày sản xuất" },
  { key: "exp_date", label: "Hạn sử dụng" },
];

const ImportHistoryDetailPage = () => {
  const { id } = useParams();
  const [log, setLog] = useState(null);
  const [loading, setLoading] = useState(true);

  const toDateSafe = (v) => {
    if (!v) return "";
    if (v.toDate) return v.toDate().toLocaleDateString();
    if (typeof v === "string") return v;
    return "";
  };

  const toDateTimeSafe = (v) => {
    if (!v) return "";
    if (v.toDate) return v.toDate().toLocaleString();
    if (typeof v === "string") return v;
    return "";
  };

  useEffect(() => {
    async function fetchDetail() {
      const ref = doc(db, "import_logs", id);
      const snap = await getDoc(ref);
      if (snap.exists()) setLog({ id: snap.id, ...snap.data() });
      setLoading(false);
    }
    fetchDetail();
  }, [id]);

  if (loading) return <div>Loading...</div>;
  if (!log) return <div>Không tìm thấy đơn nhập hàng</div>;

  const receiptNumber = log.batches?.[0]?.receipt_number || "";

  // Gom toàn bộ sản phẩm vào 1 mảng duy nhất
  const allRows = [];
  log.batches?.forEach((batch) => {
    batch.products?.forEach((p) => {
      allRows.push({
        ...p,
        batch_number: batch.batch_number,
        supplier_name: batch.supplier_name,
      });
    });
  });

  // ----- TÍNH THỐNG KÊ -----
  const totalQuantity = allRows.reduce((sum, p) => sum + (p.quantity || 0), 0);
  const totalPrice = allRows.reduce(
    (sum, p) => sum + (p.quantity || 0) * (p.price || 0),
    0
  );

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ marginBottom: 20 }}>Chi tiết nhập hàng</h2>

      {/* ----- THÔNG TIN PHIẾU NHẬP ----- */}
      <div
        style={{
          background: "#f8f9fa",
          padding: 20,
          borderRadius: 8,
          border: "1px solid #ddd",
          marginBottom: 20,
        }}
      >
        <p>
          <strong>Mã phiếu nhập:</strong> {receiptNumber}
        </p>
        <p>
          <strong>Người nhập:</strong> {log.admin_name}
        </p>
        <p>
          <strong>Email:</strong> {log.admin_email}
        </p>
        <p>
          <strong>Ngày nhập:</strong> {toDateTimeSafe(log.created_at)}
        </p>
      </div>

      {/* ----- THỐNG KÊ SẢN PHẨM ----- */}
      <div
        style={{
          display: "flex",
          gap: "20px",
          marginBottom: 20,
          padding: 15,
          background: "#e6f7ff",
          border: "1px solid #91d5ff",
          borderRadius: 8,
          fontWeight: "bold",
        }}
      >
        <div>
          Tổng số lượng sản phẩm: <span style={{ color: "#0050b3" }}>{totalQuantity}</span>
        </div>
        <div>
          Tổng giá tiền: <span style={{ color: "#0050b3" }}>{totalPrice.toLocaleString()} đ</span>
        </div>
      </div>

      {/* ----- BẢNG TỔNG HỢP CHUNG ----- */}
      <div
        style={{
          maxHeight: 650,
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
            {allRows.map((row, idx) => (
              <tr
                key={idx}
                style={{
                  backgroundColor: idx % 2 === 0 ? "#ffffff" : "#f9fafb",
                  transition: "background 0.2s",
                }}
              >
                {FIELDS.map((f) => {
                  let val = row[f.key] ?? "";

                  if (f.key === "mfg_date") val = toDateSafe(row.mfg_date);
                  if (f.key === "exp_date") val = toDateSafe(row.exp_date);

                  return (
                    <td
                      key={f.key}
                      style={{
                        padding: "8px 12px",
                        borderBottom: "1px solid #ddd",
                      }}
                    >
                      {val}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default ImportHistoryDetailPage;
