/* === GIỮ NGUYÊN GIAO DIỆN — CHỈ SỬA LOGIC: XEM LẠI → SANG TRANG RIÊNG === */
import Tesseract from "tesseract.js";
import React, { useState, useCallback, useEffect } from "react";
import * as XLSX from "xlsx";
import "../App.css";
import { useNavigate } from "react-router-dom";

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

// Unique ID
const genId = () =>
  typeof crypto !== "undefined" && crypto.randomUUID
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;

/* ------------------------------------------
   HÀM FORMAT HIỂN THỊ CHO PREVIEW (chỉ dùng ở bảng preview)
------------------------------------------- */
const formatPreviewValue = (value) => {
  if (value === null || value === undefined || value === "") return "";

  // Nếu là Date object → format đẹp
  if (value instanceof Date && !isNaN(value.getTime())) {
    return value.toLocaleDateString("vi-VN"); // → 15/03/2025
  }

  // Nếu là số → thêm dấu chấm phân cách (cho quantity, price)
  if (typeof value === "number") {
    return value.toLocaleString("vi-VN");
  }

  return String(value);
};

/**
 * FilePreview component
 */
function FilePreview({ data, onRemove, onUpdateMapping }) {
  const cols = Object.keys(data.rows[0] || {});

  const headerStyle = {
    whiteSpace: "nowrap",
    padding: "8px 12px",
    borderBottom: "2px solid #ccc",
    borderRight: "1px solid rgba(255,255,255,0.4)",
    textAlign: "left",
    position: "sticky",
    top: 0,
    backgroundColor: "#f9f9f9",
    zIndex: 2,
  };

  const cellStyle = {
    whiteSpace: "nowrap",
    padding: "6px 12px",
    borderBottom: "1px solid #eee",
    borderRight: "1px solid rgba(255,255,255,0.4)",
  };

  return (
    <div style={{ marginBottom: 30 }}>
      <h3 style={{ marginTop: 20 }}>
        Preview ({data.rows.length} dòng) - {data.file?.name || data.fileName || "(không có file)"}
      </h3>

      <div
        style={{
          maxHeight: 700,
          overflowY: "auto",
          overflowX: "auto",
          border: "1px solid #ccc",
          borderRadius: 6,
          marginBottom: 20,
        }}
      >
        <table style={{ borderCollapse: "collapse", minWidth: "100%" }}>
          <thead>
            <tr>
              {cols.length === 0 ? (
                <th style={headerStyle}>(Không có cột)</th>
              ) : (
                cols.map((col) => {
                  const mappedField = Object.keys(data.mapping).find(
                    (k) => data.mapping[k] === col
                  );
                  return (
                    <th key={`${data.id}-hdr-${col}`} style={headerStyle}>
                      <div style={{ display: "flex", gap: 8 }}>
                        <span>{col}</span>
                        <span style={{ color: "green", fontWeight: 700 }}>→</span>

                        <select
                          style={{
                            appearance: "none",
                            padding: "4px 24px 4px 8px",
                            borderRadius: 20,
                            border: "1px solid #ccc",
                            backgroundColor: "#f8f8f8",
                            cursor: "pointer",
                            fontSize: "0.9em",
                          }}
                          value={mappedField || ""}
                          onChange={(e) =>
                            onUpdateMapping(data.id, col, e.target.value)
                          }
                        >
                          <option value="">-</option>
                          {FIELDS.map((f) => (
                            <option key={f.key} value={f.key}>
                              {f.label}
                            </option>
                          ))}
                        </select>
                      </div>
                    </th>
                  );
                })
              )}
            </tr>
          </thead>

          <tbody>
            {data.rows.length === 0 ? (
              <tr>
                <td style={cellStyle}>(Không có dòng dữ liệu)</td>
              </tr>
            ) : (
              data.rows.map((r) => (
                <tr key={r.__rowId}>
                  {cols.map((col) => (
                    <td key={`${r.__rowId}-${col}`} style={cellStyle}>
                      {formatPreviewValue(r[col])}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// ======================================================
// MAIN PAGE
// ======================================================
function ImportExcelPage() {
  const [filesData, setFilesData] = useState([]);
  const navigate = useNavigate();

  const [isRestoring, setIsRestoring] = useState(true);

  useEffect(() => {
    const saved = localStorage.getItem("importFilesData");
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        setFilesData(
          parsed.map((f) => ({
            ...f,
            file: null,
          }))
        );
      } catch (e) {
        console.error("Parse error:", e);
      }
    }
    setIsRestoring(false);
  }, []);

  useEffect(() => {
    if (isRestoring) return;

    localStorage.setItem(
      "importFilesData",
      JSON.stringify(
        filesData.map((f) => ({
          id: f.id,
          fileName: f.file?.name || f.fileName,
          rows: f.rows,
          mapping: f.mapping,
        }))
      )
    );
  }, [filesData, isRestoring]);

  // -----------------------------
  // ĐỌC FILE EXCEL
  // -----------------------------
  const handleFile = useCallback((e) => {
    const selectedFiles = [...(e.target.files || [])];
    if (!selectedFiles.length) return;

    const EXTRA_FIELDS = [
      { key: "supplier_name", label: "Nhà cung cấp" },
      { key: "receipt_number", label: "Mã phiếu nhập" },
      { key: "category_description", label: "Mô tả danh mục" },
      { key: "product_description", label: "Mô tả sản phẩm" },
    ];

    selectedFiles.forEach((file) => {
      const reader = new FileReader();
      reader.onload = (evt) => {
        try {
          const workbook = XLSX.read(new Uint8Array(evt.target.result), {
            type: "array",
            cellDates: true, // Giữ Date object thật
          });
          const sheet = workbook.Sheets[workbook.SheetNames[0]];
          const jsonRaw = XLSX.utils.sheet_to_json(sheet, { defval: "" });

          const json = Array.isArray(jsonRaw)
            ? jsonRaw.map((r) => ({ ...r, __rowId: genId() }))
            : [];

          const headers = Object.keys(json[0] || {});
          const mapping = {};

          [...FIELDS, ...EXTRA_FIELDS].forEach((f) => {
            const match = headers.find((h) =>
              String(h).toLowerCase().includes(f.label.toLowerCase())
            );
            if (match) mapping[f.key] = match;
          });

          setFilesData((prev) => [
            ...prev,
            {
              id: genId(),
              file,
              rows: json,
              mapping,
            },
          ]);
        } catch (err) {
          console.error("Error reading excel:", err);
          alert("Không đọc được file: " + file.name);
        }
      };

      reader.readAsArrayBuffer(file);
    });

    e.target.value = "";
  }, []);

  const removeFile = useCallback((id) => {
    setFilesData((prev) => prev.filter((f) => f.id !== id));
  }, []);

  const updateMapping = useCallback((id, col, fKey) => {
    setFilesData((prev) =>
      prev.map((f) => {
        if (f.id !== id) return f;

        const newMap = { ...f.mapping };
        Object.keys(newMap).forEach((k) => {
          if (newMap[k] === col) delete newMap[k];
        });

        if (fKey) newMap[fKey] = col;

        return { ...f, mapping: newMap };
      })
    );
  }, []);

  // -----------------------------
  // XỬ LÝ FILE ẢNH
  // -----------------------------
  const handleImageFiles = async (e) => {
    const files = [...(e.target.files || [])];

    for (const file of files) {
      try {
        const imageURL = URL.createObjectURL(file);
        const {
          data: { text },
        } = await Tesseract.recognize(imageURL, "vie", {
          langPath: "/tessdata",
          logger: (m) => console.log(m),
        });

        const rows = await parseTextToRows(text);
        const rowsWithId = rows.map((r) => ({ ...r, __rowId: genId() }));

        setFilesData((prev) => [
          ...prev,
          {
            id: genId(),
            file,
            rows: rowsWithId,
            mapping: {},
          },
        ]);

        URL.revokeObjectURL(imageURL);
      } catch (err) {
        console.error(err);
        alert("Không đọc được file ảnh: " + file.name);
      }
    }

    e.target.value = "";
  };

  async function parseTextToRows(text) {
    const response = await fetch("/api/ai-parse", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, fields: FIELDS }),
    });

    if (!response.ok) throw new Error("AI parse failed");
    const data = await response.json();
    return data.rows || [];
  }

  const goReview = () => {
    navigate("/review-import", { state: { filesData } });
  };

  return (
    <div style={{ padding: 20 }}>
      <h2>Nhập hàng</h2>

      <input type="file" accept=".xlsx,.xls" multiple onChange={handleFile} />

      <h3>Upload ảnh phiếu nhập (AI sẽ phân tích)</h3>
      <input type="file" accept="image/*" multiple onChange={handleImageFiles} />

      {filesData.length > 0 && (
        <>
          <h4 style={{ marginTop: 20 }}>File đã chọn:</h4>
          <ul>
            {filesData.map((f) => (
              <li key={f.id}>
                {f.file?.name || f.fileName}
                <button
                  onClick={() => removeFile(f.id)}
                  style={{
                    marginLeft: 10,
                    background: "red",
                    color: "white",
                    border: "none",
                    borderRadius: 5,
                    padding: "2px 6px",
                    cursor: "pointer",
                  }}
                >
                  Xóa
                </button>
              </li>
            ))}
          </ul>

          {filesData.map((f) => (
            <FilePreview
              key={f.id}
              data={f}
              onRemove={removeFile}
              onUpdateMapping={updateMapping}
            />
          ))}

          <button
            onClick={goReview}
            style={{
              marginTop: 20,
              padding: "10px 20px",
              background: "#007bff",
              color: "white",
              border: "none",
              borderRadius: 5,
              cursor: "pointer",
            }}
          >
            Xem lại thông tin nhập hàng
          </button>
        </>
      )}
    </div>
  );
}

export default ImportExcelPage;