// src/services/employeeExportService.js

import { db } from "../firebase";
import {
  collection,
  query,
  where,
  getDocs,
  getDoc,
  doc,
  updateDoc,
  serverTimestamp,
  writeBatch,
  addDoc,
} from "firebase/firestore";

export const processStaffExport = async (cartItems, staffInfo) => {
  if (cartItems.length === 0) throw new Error("Không có lô nào để xuất");

  const batch = writeBatch(db);
  const updatedProducts = new Set();

  // Cập nhật tồn kho từng lô
  for (const item of cartItems) {
    const { batchId, exportQty } = item;

    const batchSnap = await getDoc(doc(db, "product_batches", batchId));
    if (!batchSnap.exists()) throw new Error(`Lô ${item.batchNumber} không tồn tại`);

    const batchData = batchSnap.data();
    const currentQty = batchData.quantity ?? 0;
    if (currentQty < exportQty) throw new Error(`Lô ${item.batchNumber} không đủ tồn kho`);

    batch.update(doc(db, "product_batches", batchId), {
      quantity: currentQty - exportQty,
    });

    updatedProducts.add(item.productId);
  }

  await batch.commit();

  // Cập nhật tổng tồn sản phẩm
  for (const prodId of updatedProducts) {
    const q = query(
      collection(db, "product_batches"),
      where("product_id", "==", doc(db, "products", prodId)),
      where("is_deleted", "==", false)
    );
    const snap = await getDocs(q);
    let total = 0;
    snap.forEach((d) => (total += Number(d.data().quantity ?? 0)));
    await updateDoc(doc(db, "products", prodId), { quantity: total });
  }

  const receiptNumber = `XK-${Date.now()}`;

  // Tạo cấu trúc batches giống hệt bên import_logs (admin)
  const batchesForLog = cartItems.map((item) => ({
    batch_number: item.batchNumber,
    products: [
      {
        product_id: item.productId,
        product_name: item.productName,
        category_id: item.categoryId || "",
        category_name: item.categoryName || "",
        quantity: item.exportQty,
        old_quantity: item.oldQty,
        new_quantity: item.newQty,
        mfg_date: item.mfgDate || null,
        exp_date: item.expDate || null,
      },
    ],
  }));

  // Ghi log xuất kho
  await addDoc(collection(db, "staff_export_logs"), {
    receipt_number: receiptNumber,

    // Thông tin nhân viên
    staff_id: staffInfo.id || null,
    staff_name: staffInfo.name || "Nhân viên",
    staff_email: staffInfo.email || "",
    staff_phone: staffInfo.phone || "",
    staff_role: staffInfo.role || "staff",

    // Chi tiết các lô xuất
    batches: batchesForLog,

    // Tổng xuất
    total_export: cartItems.reduce((sum, item) => sum + item.exportQty, 0),

    // Thời gian
    created_at: serverTimestamp(),
    exported_at: serverTimestamp(),
  });

  return {
    success: true,
    receiptNumber,
    totalExported: cartItems.reduce((sum, item) => sum + item.exportQty, 0),
  };
};