// src/pages/employee/EmpExportPage.js

import React, { useState, useEffect } from "react";
import { db } from "../../firebase";
import {
  collection,
  query,
  where,
  getDocs,
  orderBy,
} from "firebase/firestore";
// Bỏ import auth vì không còn dùng nữa
// import { auth } from "../../firebase";
import { processStaffExport } from "../../services/employeeExportService";
import { useNavigate } from "react-router-dom"; // Thêm để chuyển hướng an toàn

const EmpExportPage = () => {
  const navigate = useNavigate();

  const [productsByCategory, setProductsByCategory] = useState({});
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("all");
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [batches, setBatches] = useState([]);
  const [batchQtyMap, setBatchQtyMap] = useState({});
  const [exportCart, setExportCart] = useState([]);
  const [confirming, setConfirming] = useState(false);
  const [showCart, setShowCart] = useState(true);
  const [batchesByProduct, setBatchesByProduct] = useState({});

  const [staffInfo, setStaffInfo] = useState({
    id: "",
    name: "Nhân viên",
    email: "",
    phone: "",
    role: "staff",
  });

  // ← THAY TOÀN BỘ useEffect cũ BẰNG ĐOẠN NÀY (đọc từ localStorage)
  useEffect(() => {
    const sessionData = localStorage.getItem("employeeUser");

    if (!sessionData) {
      alert("Phiên đăng nhập hết hạn hoặc chưa đăng nhập. Vui lòng đăng nhập lại.");
      navigate("/employee/login");
      return;
    }

    try {
      const session = JSON.parse(sessionData);

      // Kiểm tra hết hạn session (1 giờ như ở login)
      if (session.expiresAt && Date.now() > session.expiresAt) {
        localStorage.removeItem("employeeUser");
        alert("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.");
        navigate("/employee/login");
        return;
      }

      // Lấy thông tin nhân viên từ session (đã lưu đầy đủ email + phone ở login)
      setStaffInfo({
        id: session.id || "",
        name: session.fullname || "Nhân viên",
        email: session.email || "",
        phone: session.phone || "",
        role: session.role || "staff",
      });
    } catch (error) {
      console.error("Lỗi parse session nhân viên:", error);
      localStorage.removeItem("employeeUser");
      alert("Dữ liệu đăng nhập bị lỗi. Vui lòng đăng nhập lại.");
      navigate("/employee/login");
    }
  }, [navigate]); // Chỉ chạy một lần khi component mount


  // Bỏ dấu tiếng Việt
  const removeDiacritics = (str) => {
    if (!str) return "";
    return str
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/đ/g, "d")
      .replace(/Đ/g, "D");
  };

  // Format ngày
  const formatDate = (dateField) => {
    if (!dateField) return "-";
    if (typeof dateField === "string") {
      return dateField.split("-").reverse().join("/");
    }
    if (dateField.toDate) {
      return dateField.toDate().toLocaleDateString("vi-VN");
    }
    return "-";
  };

  // Tính số ngày còn lại đến hạn sử dụng
// Tính số ngày còn lại đến hạn sử dụng - HỖ TRỢ NHIỀU ĐỊNH DẠNG
const daysUntilExpiry = (expDate) => {
  if (!expDate) return Infinity;

  let date;

  // Trường hợp 1: Firebase Timestamp
  if (expDate.toDate) {
    date = expDate.toDate();
  }
  // Trường hợp 2: String dạng DD/MM/YYYY (hiển thị)
  else if (typeof expDate === "string") {
    // Thử DD/MM/YYYY trước
    if (expDate.includes("/")) {
      const parts = expDate.split("/");
      if (parts.length === 3) {
        const [d, m, y] = parts.map(Number);
        if (!isNaN(d) && !isNaN(m) && !isNaN(y)) {
          date = new Date(y, m - 1, d);
        }
      }
    }
    // Thử YYYY-MM-DD (dữ liệu gốc thường gặp)
    else if (expDate.includes("-")) {
      const parts = expDate.split("-");
      if (parts.length === 3) {
        const [y, m, d] = parts.map(Number);
        if (!isNaN(d) && !isNaN(m) && !isNaN(y)) {
          date = new Date(y, m - 1, d);
        }
      }
    }
  }

  // Nếu không parse được
  if (!date || isNaN(date.getTime())) return Infinity;

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  date.setHours(0, 0, 0, 0); // chuẩn hóa

  const diff = date - today;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
};

  // ================= TẢI DỮ LIỆU =================
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        const catSnap = await getDocs(
          query(collection(db, "categories"), where("is_deleted", "==", false), orderBy("name"))
        );
        const cats = catSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
        setCategories([
          { id: "all", name: "Tất cả" },
          ...cats,
          { id: "uncategorized", name: "Không phân loại" },
        ]);

        const prodSnap = await getDocs(
          query(collection(db, "products"), where("is_deleted", "==", false), orderBy("name"))
        );
        const prods = prodSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

        const batchSnap = await getDocs(
          query(collection(db, "product_batches"), where("is_deleted", "==", false))
        );
        const allBatches = batchSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

        const batchesMap = {};
        allBatches.forEach((batch) => {
          if (!batchesMap[batch.product_id]) batchesMap[batch.product_id] = [];
          batchesMap[batch.product_id].push(batch);
        });
        setBatchesByProduct(batchesMap);

        const grouped = {};
        cats.forEach((cat) => {
          grouped[cat.id] = {
            category: cat,
            products: prods.filter((p) => p.category_id === cat.id),
          };
        });

        const noCatProducts = prods.filter((p) => !p.category_id);
        if (noCatProducts.length > 0) {
          grouped["uncategorized"] = {
            category: { id: "uncategorized", name: "Không phân loại" },
            products: noCatProducts,
          };
        }

        setProductsByCategory(grouped);
      } catch (e) {
        console.error("Lỗi tải dữ liệu:", e);
        alert("Không tải được dữ liệu sản phẩm");
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  // ================= LỌC DỮ LIỆU =================
  const normalizedSearch = removeDiacritics(searchTerm.toLowerCase());

  const filteredGroups = Object.entries(productsByCategory)
    .filter(([catId]) => selectedCategory === "all" || catId === selectedCategory)
    .filter(([_, group]) => {
      return group.products.some((prod) => {
        const batches = batchesByProduct[prod.id] || [];
        const productMatch = removeDiacritics(prod.name.toLowerCase()).includes(normalizedSearch);

        const batchMatches = batches.some((batch) => {
          return (
            removeDiacritics(batch.batch_number || "").toLowerCase().includes(normalizedSearch) ||
            batch.quantity.toString().includes(searchTerm) ||
            removeDiacritics(formatDate(batch.mfg_date)).includes(normalizedSearch) ||
            removeDiacritics(formatDate(batch.expiry_date)).includes(normalizedSearch)
          );
        });

        return productMatch || batchMatches;
      });
    });

  // ================= CÁC HÀM XỬ LÝ =================
const openBatchModal = async (product) => {
  try {
    const batchSnap = await getDocs(
      query(
        collection(db, "product_batches"),
        where("product_id", "==", product.id),
        where("is_deleted", "==", false)
      )
    );

    const allBatchList = batchSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    // Chỉ giữ lại các lô có tồn kho > 0
    const validBatches = allBatchList.filter((batch) => batch.quantity > 0);

    setBatches(validBatches);
    setSelectedProduct(product);
    setBatchQtyMap({});

    // Nếu không có lô nào còn hàng → vẫn mở modal nhưng hiển thị thông báo
    // (giữ nguyên hành vi hiện tại)
  } catch (e) {
    alert("Lỗi tải lô hàng");
    console.error(e);
  }
};

const addToCart = (batch) => {
  const qty = batchQtyMap[batch.id] || 0;
  if (qty <= 0 || qty > batch.quantity) {
    alert("Số lượng không hợp lệ hoặc vượt quá tồn kho");
    return;
  }

  // Tìm tên danh mục từ mảng categories (đã load sẵn ở đầu file)
  // categories có dạng: [{ id: "abc123", name: "Văn phòng phẩm" }, ...]
  const category = categories.find(cat => cat.id === selectedProduct.category_id);
  const categoryName = category ? category.name : "Không phân loại";

  const item = {
    productId: selectedProduct.id,
    productName: selectedProduct.name,
    productPrice: selectedProduct.price || 0,
    batchId: batch.id,
    batchNumber: batch.batch_number,
    exportQty: qty,
    oldQty: batch.quantity,
    newQty: batch.quantity - qty,
    mfgDate: batch.mfg_date,
    expDate: batch.expiry_date,

    // ← LƯU ĐẦY ĐỦ THÔNG TIN DANH MỤC
    categoryId: selectedProduct.category_id || "",          // ID danh mục từ product
    categoryName: categoryName,                             // Tên danh mục thực tế (từ categories)
  };

  setExportCart((prev) => [...prev, item]);
  setBatchQtyMap((prev) => ({ ...prev, [batch.id]: 0 }));

  alert(`Đã thêm ${qty} sản phẩm từ lô ${batch.batch_number} vào giỏ hàng!`);
};

  const updateCartQty = (index, newQty) => {
    if (newQty < 1 || newQty > exportCart[index].oldQty) return;
    setExportCart((prev) =>
      prev.map((item, i) =>
        i === index
          ? { ...item, exportQty: newQty, newQty: item.oldQty - newQty }
          : item
      )
    );
  };

  const removeFromCart = (index) => {
    setExportCart((prev) => prev.filter((_, i) => i !== index));
  };

  const handleConfirmExport = async () => {
    if (exportCart.length === 0) {
      alert("Giỏ xuất kho trống");
      return;
    }

    if (!window.confirm(`Xác nhận xuất kho ${exportCart.reduce((s, i) => s + i.exportQty, 0)} sản phẩm?`)) {
      return;
    }

    setConfirming(true);
    try {
      const result = await processStaffExport(exportCart, staffInfo);
      alert(
        `Xuất kho thành công!\nMã phiếu: ${result.receiptNumber}\nTổng xuất: ${result.totalExported} sản phẩm`
      );
      setExportCart([]);
      window.location.reload();
    } catch (err) {
      alert("Lỗi xuất kho: " + err.message);
    } finally {
      setConfirming(false);
    }
  };

  const clearSearch = () => {
    setSearchTerm("");
  };

  const totalInCart = exportCart.reduce((sum, item) => sum + item.exportQty, 0);

  // ================= STYLES =================
  const styles = {
    container: {
      padding: "20px",
      background: "var(--bg-color, #f5f7fa)",
      minHeight: "100vh",
      fontFamily: "Arial, sans-serif",
      color: "var(--text-color, #333)",
    },
    title: {
      textAlign: "center",
      margin: "20px 0 30px",
      color: "var(--primary-color, #2e7d32)",
      fontSize: "1.8em",
    },
    searchBarContainer: {
      maxWidth: 800,
      margin: "0 auto 40px",
      display: "flex",
      flexDirection: "column",
      gap: "20px",
      alignItems: "center",
    },
    searchInputWrapper: {
      width: "100%",
      position: "relative",
    },
    searchInput: {
      width: "100%",
      padding: "14px 50px 14px 45px",
      fontSize: "1.1em",
      border: "1px solid var(--border-color, #bbb)",
      borderRadius: 10,
      background: "var(--input-bg, #fff)",
      color: "var(--text-color, #333)",
      boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
      outline: "none",
      transition: "all 0.2s",
    },
    categorySelect: {
      width: "100%",
      maxWidth: 500,
      padding: "14px 18px",
      fontSize: "1.1em",
      border: "1px solid var(--border-color, #bbb)",
      borderRadius: 10,
      background: "var(--input-bg, #fff)",
      cursor: "pointer",
      boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
      outline: "none",
      transition: "all 0.2s",
    },
    searchIcon: {
      position: "absolute",
      left: 16,
      top: "50%",
      transform: "translateY(-50%)",
      fontSize: "1.4em",
      color: "#666",
      pointerEvents: "none",
    },
    clearIcon: {
      position: "absolute",
      right: 16,
      top: "50%",
      transform: "translateY(-50%)",
      fontSize: "1.4em",
      color: "#999",
      cursor: "pointer",
      background: "none",
      border: "none",
      padding: 0,
      lineHeight: 1,
      opacity: searchTerm ? 1 : 0,
      pointerEvents: searchTerm ? "auto" : "none",
      transition: "opacity 0.2s",
    },

    loadingText: { textAlign: "center", fontSize: "1.2em", color: "#555" },
    tableWrapper: {
      marginBottom: 50,
      border: "1px solid var(--border-color, #999)",
      borderRadius: 10,
      overflow: "hidden",
      boxShadow: "0 4px 15px rgba(0,0,0,0.1)",
    },
    table: { width: "100%", borderCollapse: "collapse", background: "var(--table-bg, #fff)" },
    categoryHeader: {
      background: "var(--primary-color, #2e7d32)",
      color: "white",
      padding: "16px",
      fontSize: "1.4em",
      fontWeight: "bold",
      textAlign: "center",
    },
    headerRow: { background: "var(--header-bg, #a5d6a7)", height: 50 },
    th: {
      padding: "12px 16px",
      textAlign: "center",
      border: "1px solid var(--border-color, #999)",
      fontWeight: "bold",
      color: "var(--header-text, #1a3d1a)",
      whiteSpace: "nowrap",
    },
    evenRow: { backgroundColor: "var(--row-even, #f8fff8)" },
    oddRow: { backgroundColor: "var(--row-odd, #fff)" },
    // ĐÃ CHỈNH: tăng độ dày và thêm border trên/dưới cho khối sản phẩm
    productCell: {
      fontWeight: "bold",
      backgroundColor: "var(--product-bg, #e8f5e8)",
      borderLeft: "6px double var(--primary-color, #2e7d32)",
      borderRight: "6px double var(--primary-color, #2e7d32)",
      cursor: "pointer",
      padding: "12px 16px",
      textAlign: "center",
      verticalAlign: "middle",
    },
    productName: { color: "var(--primary-color, #2e7d32)", fontSize: "1.05em" },
    productPrice: { fontSize: "0.9em", color: "#666" },
    td: {
      padding: "12px 16px",
      textAlign: "center",
      border: "1px solid var(--border-color, #bbb)",
      verticalAlign: "middle",
    },
    summaryCell: {
      fontWeight: "bold",
      fontSize: "1.1em",
      backgroundColor: "#e8f5e8",
      minWidth: "120px",
    },
    outOfStockSummary: {
      backgroundColor: "#ffcdd2",
      color: "#c00000",
    },
    lowStockSummary: {
      backgroundColor: "#fff3e0",
      color: "#ffa71aff",
    },
    nearExpirySummary: {
      backgroundColor: "#ffebee",
      color: "#c00000",
      animation: "blink 1.5s infinite",
    },
    emptyRow: {
      padding: 30,
      textAlign: "center",
      color: "#888",
      border: "1px solid var(--border-color, #bbb)",
    },
    cartContainer: {
      margin: "40px 0 20px",
      borderRadius: 12,
      overflow: "hidden",
      boxShadow: "0 6px 20px rgba(0,0,0,0.12)",
      background: "var(--card-bg, #fff)",
    },
    cartHeader: {
      background: "var(--primary-color, #2e7d32)",
      color: "white",
      padding: "16px 24px",
      fontSize: "1.3em",
      fontWeight: "bold",
      cursor: "pointer",
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
    },
    toggleIcon: { fontSize: "1.5em" },
    cartContent: { padding: 20 },
    cartTableWrapper: { overflow: "auto", maxHeight: "60vh", border: "1px solid var(--border-color, #ddd)", borderRadius: 8 },
    qtyInput: {
      width: 90,
      padding: "8px",
      textAlign: "center",
      border: "1px solid var(--border-color, #aaa)",
      borderRadius: 6,
      background: "var(--input-bg, #fff)",
    },
    deleteBtn: {
      background: "#c00000",
      color: "white",
      border: "none",
      padding: "8px 16px",
      borderRadius: 6,
      cursor: "pointer",
    },
    confirmButtonWrapper: { textAlign: "center", marginTop: 24 },
    confirmBtn: {
      padding: "16px 60px",
      background: "var(--primary-color, #2e7d32)",
      color: "white",
      border: "none",
      borderRadius: 10,
      fontSize: "1.4em",
      fontWeight: "bold",
      cursor: "pointer",
      boxShadow: "0 4px 12px rgba(46, 125, 50, 0.3)",
    },
    confirmBtnDisabled: {
      padding: "16px 60px",
      background: "#999",
      color: "white",
      border: "none",
      borderRadius: 10,
      fontSize: "1.4em",
      fontWeight: "bold",
      cursor: "not-allowed",
    },
    addBtn: {
      padding: "10px 24px",
      background: "var(--primary-color, #2e7d32)",
      color: "white",
      border: "none",
      borderRadius: 8,
      fontWeight: "bold",
      cursor: "pointer",
    },
    addBtnDisabled: {
      padding: "10px 24px",
      background: "#aaa",
      color: "white",
      border: "none",
      borderRadius: 8,
      fontWeight: "bold",
      cursor: "not-allowed",
    },
    modalOverlay: {
      position: "fixed",
      inset: 0,
      background: "rgba(0,0,0,0.7)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      zIndex: 1000,
    },
    modal: {
      background: "var(--card-bg, #fff)",
      width: "90%",
      maxWidth: 900,
      maxHeight: "85vh",
      overflowY: "auto",
      borderRadius: 16,
      boxShadow: "0 10px 40px rgba(0,0,0,0.3)",
    },
    modalHeader: {
      background: "var(--primary-color, #2e7d32)",
      color: "white",
      padding: "18px 30px",
      borderRadius: "16px 16px 0 0",
      fontSize: "1.4em",
      fontWeight: "bold",
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
    },
    modalClose: { background: "none", border: "none", color: "white", fontSize: "2em", cursor: "pointer" },
    modalBody: { padding: 30 },
    emptyModal: { textAlign: "center", padding: 50, color: "#777", fontSize: "1.1em" },
  };

  // Thêm animation nhấp nháy
  useEffect(() => {
    const style = document.createElement("style");
    style.innerHTML = `
      @keyframes blink {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.6; }
      }
    `;
    document.head.appendChild(style);
    return () => document.head.removeChild(style);
  }, []);

  // ================= RETURN JSX =================
  return (
    <div style={styles.container}>
      <h2 style={styles.title}>XUẤT KHO NHÂN VIÊN</h2>

      <div style={styles.searchBarContainer}>
        <div style={styles.searchInputWrapper}>
          <span style={styles.searchIcon}></span>
          <input
            type="text"
            placeholder="Tìm kiếm..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={styles.searchInput}
          />
          <button
            onClick={clearSearch}
            style={styles.clearIcon}
            aria-label="Xóa tìm kiếm"
          >
            ×
          </button>
        </div>

        <select
          value={selectedCategory}
          onChange={(e) => setSelectedCategory(e.target.value)}
          style={styles.categorySelect}
        >
          {categories.map((cat) => (
            <option key={cat.id} value={cat.id}>
              {cat.name}
            </option>
          ))}
        </select>
      </div>

      {loading ? (
        <p style={styles.loadingText}>Đang tải dữ liệu sản phẩm...</p>
      ) : filteredGroups.length === 0 ? (
        <p style={styles.loadingText}>Không tìm thấy sản phẩm nào phù hợp.</p>
      ) : (
        <>


        
        {/* === CHÚ THÍCH HƯỚNG DẪN (đã chỉnh đơn giản, căn trái, không khung) === */}
          <div style={{
            textAlign: "left",
            margin: "30px 0 40px 20px",  // cách lề trái một chút cho dễ đọc
            fontSize: "1.1em",
            color: "#333",
            fontWeight: "normal",
            lineHeight: "1.6",
          }}>
            Hướng dẫn: Nhấn vào tên sản phẩm (cột đầu tiên) để mở danh sách lô hàng và chọn số lượng xuất kho.
          </div>

          
          {filteredGroups.map(([catId, group]) => (
            <div key={catId} style={styles.tableWrapper}>
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th colSpan={7} style={styles.categoryHeader}>
                      {group.category.name.toUpperCase()}
                    </th>
                  </tr>
                  <tr style={styles.headerRow}>
                    <th style={styles.th}>Sản phẩm</th>
                    <th style={styles.th}>Mã lô</th>
                    <th style={styles.th}>Ngày nhập</th>
                    <th style={styles.th}>Ngày SX</th>
                    <th style={styles.th}>Hạn SD</th>
                    <th style={styles.th}>Tồn kho</th>
                    <th style={styles.th}>Tổng SL</th>
                  </tr>
                </thead>

              <tbody>
                {group.products.flatMap((prod) => {
                  const allBatches = batchesByProduct[prod.id] || [];

                  // Lọc chỉ lấy các lô có quantity > 0
                  const validBatches = allBatches.filter((b) => b.quantity > 0);

                  // Tính tổng tồn kho
                  const totalQty = allBatches.reduce((sum, b) => sum + b.quantity, 0);
                  const isOutOfStock = totalQty === 0;
                  const isLowStock = totalQty > 0 && totalQty <= 10;

                  // Cột Tổng quan
                  let summaryText = isOutOfStock ? "Hết hàng" : isLowStock ? `Sắp hết (${totalQty})` : `${totalQty}`;
                  let summaryStyle = { ...styles.summaryCell };
                  if (isOutOfStock) {
                    summaryStyle = { ...summaryStyle, ...styles.outOfStockSummary };
                  } else if (isLowStock) {
                    summaryStyle = { ...summaryStyle, ...styles.lowStockSummary };
                  }

                  // Hàm trả về style nền cho từng lô
                  const getBatchRowStyle = (daysLeft) => {
                    if (daysLeft <= 0) {
                      return { backgroundColor: "#ffcdd2" }; // Đỏ nhạt - hết hạn
                    }
                    
                    if (daysLeft <= 30 && daysLeft > 0) {
                      return { backgroundColor: "#af9b59ff" }; // Vàng sáng nhẹ - sắp hết hạn (mình đổi từ #fff3cd sang màu sáng hơn, dễ nhìn hơn)
                    }
                    return {};
                  };

                  // Hàm trả về style chữ riêng cho cột Hạn SD
                  const getExpiryTextStyle = (daysLeft) => {
                    if (daysLeft <= 0) {
                      return { color: "#c00000", fontWeight: "bold" }; // Chỉ hết hạn mới đỏ đậm
                    }
                    return {}; // Sắp hết hạn: chữ bình thường
                  };

                  // Trường hợp hết hàng
                  if (validBatches.length === 0) {
                    return (
                      <tr key={prod.id}>
                        <td
                          style={{
                            ...styles.productCell,
                            borderTop: "4px double var(--primary-color, #2e7d32)",
                            borderBottom: "4px double var(--primary-color, #2e7d32)",
                          }}
                          onClick={() => openBatchModal(prod)}
                        >
                          <div style={styles.productName}>{prod.name}</div>
                          <div style={styles.productPrice}>
                            Giá: {prod.price?.toLocaleString() || 0} đ
                          </div>
                        </td>
                        <td colSpan={5} style={styles.td}></td>
                        <td style={{ ...styles.td, whiteSpace: "pre-wrap", ...summaryStyle }}>
                          {summaryText}
                        </td>
                      </tr>
                    );
                  }

                  // Có lô còn hàng
                  return validBatches.map((batch, idx) => {
                    const daysLeft = daysUntilExpiry(batch.expiry_date);
                    const isThisBatchNearExpiry = daysLeft <= 10 && daysLeft > 0;
                    const isThisBatchExpired = daysLeft <= 0;

                    const rowStyle = idx % 2 === 0 ? styles.evenRow : styles.oddRow;
                    const extraRowStyle = idx === 0 ? { borderTop: "4px double var(--primary-color, #2e7d32)" } : {};
                    const batchHighlightStyle = getBatchRowStyle(daysLeft);
                    const expiryTextStyle = getExpiryTextStyle(daysLeft);

                    return (
                      <tr
                        key={batch.id}
                        style={{ ...rowStyle, ...extraRowStyle, ...batchHighlightStyle }}
                      >
                        {/* Cột Sản phẩm */}
                        {idx === 0 && (
                          <td
                            rowSpan={validBatches.length}
                            style={{
                              ...styles.productCell,
                              borderBottom: validBatches.length === 1 ? "4px double var(--primary-color, #2e7d32)" : "none",
                            }}
                            onClick={() => openBatchModal(prod)}
                          >
                            <div style={styles.productName}>{prod.name}</div>
                            <div style={styles.productPrice}>
                              Giá: {prod.price?.toLocaleString() || 0} đ
                            </div>
                          </td>
                        )}

                        {/* Các cột lô */}
                        <td style={{ ...styles.td, ...batchHighlightStyle }}>
                          {batch.batch_number || "-"}
                        </td>
                        <td style={{ ...styles.td, ...batchHighlightStyle }}>
                          {batch.created_at?.seconds
                            ? new Date(batch.created_at.seconds * 1000).toLocaleDateString("vi-VN")
                            : "-"}
                        </td>
                        <td style={{ ...styles.td, ...batchHighlightStyle }}>
                          {formatDate(batch.mfg_date)}
                        </td>
                        <td
                          style={{
                            ...styles.td,
                            ...batchHighlightStyle,
                            ...expiryTextStyle, // Chỉ hết hạn mới đỏ đậm
                          }}
                        >
                          {formatDate(batch.expiry_date)}
                          {isThisBatchExpired && " (Đã hết hạn)"}
                          {isThisBatchNearExpiry && !isThisBatchExpired && " (Sắp hết hạn)"}
                        </td>
                        <td style={{ ...styles.td, ...batchHighlightStyle }}>
                          {batch.quantity}
                        </td>

                        {/* Cột Tổng quan */}
                        {idx === 0 && (
                          <td
                            rowSpan={validBatches.length}
                            style={{ ...styles.td, whiteSpace: "pre-wrap", ...summaryStyle }}
                          >
                            {summaryText}
                          </td>
                        )}
                      </tr>
                    );
                  });
                })}
              </tbody>


              </table>
            </div>
          ))}
        </>
      )}

      {/* Giỏ xuất kho */}
      {exportCart.length > 0 && (
        <div style={styles.cartContainer}>
          <div onClick={() => setShowCart(!showCart)} style={styles.cartHeader}>
            <span>🛒 Giỏ xuất kho ({exportCart.length} lô - Tổng số lượng: {totalInCart})</span>
            <span style={styles.toggleIcon}>{showCart ? "−" : "+"}</span>
          </div>

          {showCart && (
            <div style={styles.cartContent}>
              <div style={styles.cartTableWrapper}>
                <table style={styles.table}>
                  <thead>
                    <tr style={styles.headerRow}>
                      <th style={styles.th}>Sản phẩm</th>
                      <th style={styles.th}>Lô</th>
                      <th style={styles.th}>Ngày SX</th>
                      <th style={styles.th}>Hạn SD</th>
                      <th style={styles.th}>Tồn trước</th>
                      <th style={styles.th}>SL xuất</th>
                      <th style={styles.th}>Còn lại</th>
                      <th style={styles.th}>Hành động</th>
                    </tr>
                  </thead>
                  <tbody>
                    {exportCart.map((item, idx) => (
                      <tr key={idx} style={idx % 2 === 0 ? styles.evenRow : styles.oddRow}>
                        <td style={styles.td}>{item.productName}</td>
                        <td style={styles.td}>{item.batchNumber}</td>
                        <td style={styles.td}>{formatDate(item.mfgDate)}</td>
                        <td style={styles.td}>{formatDate(item.expDate)}</td>
                        <td style={styles.td}>{item.oldQty}</td>
                        <td style={styles.td}>
                          <input
                            type="number"
                            min="1"
                            max={item.oldQty}
                            value={item.exportQty}
                            onChange={(e) =>
                              updateCartQty(idx, Math.max(1, Math.min(item.oldQty, Number(e.target.value) || 1)))
                            }
                            style={styles.qtyInput}
                          />
                        </td>
                        <td style={{ ...styles.td, fontWeight: "bold" }}>{item.newQty}</td>
                        <td style={styles.td}>
                          <button onClick={() => removeFromCart(idx)} style={styles.deleteBtn}>
                            Xóa
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div style={styles.confirmButtonWrapper}>
                <button
                  onClick={handleConfirmExport}
                  disabled={confirming}
                  style={confirming ? styles.confirmBtnDisabled : styles.confirmBtn}
                >
                  {confirming ? "Đang xử lý..." : "XÁC NHẬN XUẤT KHO"}
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Modal chọn lô */}
      {selectedProduct && (
        <div style={styles.modalOverlay}>
          <div style={styles.modal}>
            <div style={styles.modalHeader}>
              <span>Chọn lô xuất kho - {selectedProduct.name}</span>
              <button onClick={() => setSelectedProduct(null)} style={styles.modalClose}>
                ×
              </button>
            </div>
            <div style={styles.modalBody}>
      {batches.length === 0 ? (
        <p style={styles.emptyModal}>
          Không có lô hàng nào còn tồn kho cho sản phẩm này
        </p>
      ) : (
        <div style={styles.cartTableWrapper}>
          <table style={styles.table}>
            <thead>
              <tr style={styles.headerRow}>
                <th style={styles.th}>Mã lô</th>
                <th style={styles.th}>Tồn kho</th>
                <th style={styles.th}>Ngày SX</th>
                <th style={styles.th}>Hạn SD</th>
                <th style={styles.th}>Số lượng xuất</th>
                <th style={styles.th}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {batches.map((batch, index) => (
                <tr key={batch.id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                  <td style={styles.td}>{batch.batch_number || "-"}</td>
                  <td style={{ ...styles.td, fontWeight: "bold", color: "var(--primary-color, #2e7d32)" }}>
                    {batch.quantity}
                  </td>
                  <td style={styles.td}>{formatDate(batch.mfg_date)}</td>
                  <td style={styles.td}>{formatDate(batch.expiry_date)}</td>
                  <td style={styles.td}>
                    <input
                      type="number"
                      min="0"
                      max={batch.quantity}
                      value={batchQtyMap[batch.id] || 0}
                      onChange={(e) =>
                        setBatchQtyMap((prev) => ({
                          ...prev,
                          [batch.id]: Math.max(0, Math.min(Number(e.target.value || 0), batch.quantity)),
                        }))
                      }
                      style={styles.qtyInput}
                    />
                  </td>
                  <td style={styles.td}>
                    <button
                      onClick={() => addToCart(batch)}
                      disabled={!batchQtyMap[batch.id] || batchQtyMap[batch.id] <= 0 || batchQtyMap[batch.id] > batch.quantity}
                      style={batchQtyMap[batch.id] > 0 && batchQtyMap[batch.id] <= batch.quantity ? styles.addBtn : styles.addBtnDisabled}
                    >
                      Thêm vào giỏ
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
                  </div>
                </div>
              </div>
            )}
          </div>
        );
      };

// Dark mode CSS
const styleTag = document.createElement("style");
styleTag.innerHTML = `
  @media (prefers-color-scheme: dark) {
    :root {
      --bg-color: #121212;
      --text-color: #e0e0e0;
      --table-bg: #1e1e1e;
      --card-bg: #1e1e1e;
      --input-bg: #2d2d2d;
      --border-color: #444;
      --header-bg: #388e3c;
      --header-text: #ffffff;
      --primary-color: #66bb6a;
      --row-even: #2a2a2a;
      --row-odd: #242424;
      --product-bg: #2d4a2d;
    }
  }
  @media (prefers-color-scheme: light) {
    :root {
      --bg-color: #f5f7fa;
      --text-color: #333;
      --table-bg: #fff;
      --card-bg: #fff;
      --input-bg: #fff;
      --border-color: #bbb;
      --header-bg: #a5d6a7;
      --header-text: #1a3d1a;
      --primary-color: #2e7d32;
      --row-even: #f8fff8;
      --row-odd: #fff;
      --product-bg: #e8f5e8;
    }
  }
`;
document.head.appendChild(styleTag);

export default EmpExportPage;