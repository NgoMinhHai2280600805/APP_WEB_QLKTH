import React, { useEffect, useState } from "react";
import { db } from "../firebase";
import { collection, getDocs, orderBy, query } from "firebase/firestore";
import { Link } from "react-router-dom";

const ImportHistoryPage = () => {
  const [logs, setLogs] = useState([]);
  const [filtered, setFiltered] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  const toDateTimeSafe = (value) => {
    if (!value) return "";
    if (value?.toDate) return value.toDate().toLocaleString();
    if (typeof value === "string") return value;
    return "";
  };

  useEffect(() => {
    const fetchLogs = async () => {
      const q = query(collection(db, "import_logs"), orderBy("created_at", "desc"));
      const snap = await getDocs(q);
      const data = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      setLogs(data);
      setFiltered(data);
      setLoading(false);
    };
    fetchLogs();
  }, []);

  const normalizeStr = (str) => {
    if (!str) return "";
    return str
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase();
  };

  useEffect(() => {
    const s = normalizeStr(search);
    const result = logs.filter(
      (log) =>
        normalizeStr(log.batches?.[0]?.receipt_number).includes(s) ||
        normalizeStr(log.admin_name).includes(s) ||
        normalizeStr(toDateTimeSafe(log.created_at)).includes(s)
    );
    setFiltered(result);
  }, [search, logs]);

  if (loading) return <div>Loading...</div>;

  return (
    <div style={{ padding: "20px" }}>
      <h2 style={{ marginBottom: "20px" }}>Lịch sử</h2>

      {/* Thanh tìm kiếm kiểu Google */}
      <div style={{ position: "relative", width: "100%", maxWidth: 600, marginBottom: 16 }}>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#9aa0a6"
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
          style={{
            position: "absolute",
            left: 12,
            top: "50%",
            transform: "translateY(-50%)",
            width: 20,
            height: 20,
            pointerEvents: "none",
          }}
        >
          <circle cx="11" cy="11" r="8" />
          <line x1="21" y1="21" x2="16.65" y2="16.65" />
        </svg>

        <input
          type="search"
          placeholder="Tìm kiếm mã phiếu, người nhập hoặc ngày..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{
            width: "100%",
            padding: "10px 12px 10px 40px",
            borderRadius: 24,
            border: "1px solid #ccc",
            fontSize: 15,
            outline: "none",
            boxShadow: "0 1px 6px rgba(32,33,36,0.28)",
          }}
        />
      </div>

      {filtered.length === 0 && <p>Không tìm thấy dữ liệu</p>}

      <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
        {filtered.map((log) => (
          <Link
            key={log.id}
            to={`/history/${log.id}`}
            className="log-item"
          >
            <p style={{ margin: "4px 0" }}>
              <strong>Mã phiếu nhập:</strong> {log.batches?.[0]?.receipt_number}
            </p>
            <p style={{ margin: "4px 0" }}>
              <strong>Người nhập:</strong> {log.admin_name ?? "(Không có tên)"}
            </p>
            <p style={{ margin: "4px 0", color: "#555" }}>
              <strong>Ngày nhập:</strong> {toDateTimeSafe(log.created_at)}
            </p>
          </Link>
        ))}
      </div>

      {/* CSS hover mượt */}
      <style>
        {`
          .log-item {
            display: block;
            padding: 12px 16px;
            border: 1px solid #ddd;
            border-radius: 10px;
            background: #fff;
            text-decoration: none;
            color: black;
            transition: background 0.25s ease;
          }
          .log-item:hover {
            background: #f1f3f5; /* sáng nhẹ lên */
          }
        `}
      </style>
    </div>
  );
};

export default ImportHistoryPage;
