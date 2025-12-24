// admin_web/src/services/importService.js

import { db } from "../firebase";
import {
  collection,
  query,
  where,
  getDocs,
  addDoc,
  updateDoc,
  doc,
  serverTimestamp,
  Timestamp, // ← Thêm Timestamp để dùng
} from "firebase/firestore";

/*------------------------------------------
    HÀM CHUẨN HÓA NGÀY THÁNG - HỖ TRỢ NHIỀU ĐỊNH DẠNG
-------------------------------------------*/
const parseFlexibleDate = (input) => {
  if (!input || input === "" || input === null || input === undefined) return null;

  // 1. Nếu đã là Timestamp rồi → trả về luôn
  if (input instanceof Timestamp) return input;

  // 2. Nếu là Date object hợp lệ
  if (input instanceof Date && !isNaN(input.getTime())) {
    return Timestamp.fromDate(input);
  }

  // 3. Nếu là số → Excel serial date (ngày bắt đầu từ 1/1/1900)
  if (typeof input === "number") {
    // Excel có bug leap year 1900 → trừ 1 ngày nếu serial >= 60
    const utc_days = Math.floor(input - (input >= 60 ? 1 : 0));
    const utc_value = utc_days * 86400000; // milliseconds trong 1 ngày
    const date = new Date(utc_value);
    if (!isNaN(date.getTime())) {
      return Timestamp.fromDate(date);
    }
  }

  // 4. Nếu là chuỗi → thử parse các định dạng phổ biến
  if (typeof input === "string") {
    const trimmed = input.trim();
    if (trimmed === "") return null;

    // Thay thế các dấu gạch bằng dấu gạch chéo để browser parse đúng
    const normalized = trimmed.replace(/-/g, "/");

    // Thử parse trực tiếp (hỗ trợ DD/MM/YYYY, YYYY/MM/DD, MM/DD/YYYY, ISO, v.v.)
    const parsed = new Date(normalized);
    if (!isNaN(parsed.getTime())) {
      return Timestamp.fromDate(parsed);
    }
  }

  // Không parse được → log cảnh báo và trả về null
  console.warn("Không thể parse ngày tháng:", input);
  return null;
};

/*------------------------------------------
    1. TÌM CATEGORY (hoặc tạo mới)
-------------------------------------------*/
export const findOrCreateCategory = async (categoryName, categoryDescription = "") => {
  if (!categoryName) return null;

  const q = query(
    collection(db, "categories"),
    where("name", "==", categoryName),
    where("is_deleted", "==", false)
  );
  const snap = await getDocs(q);

  if (!snap.empty) return snap.docs[0].id;

  const newCategory = await addDoc(collection(db, "categories"), {
    name: categoryName,
    description: categoryDescription,
    is_deleted: false,
    created_at: serverTimestamp(),
  });

  return newCategory.id;
};

/*------------------------------------------
    2. TÌM PRODUCT (hoặc tạo mới)
-------------------------------------------*/
export const findOrCreateProduct = async (name, categoryId, price = 0, productDescription = "") => {
  if (!name || !categoryId) return null;

  const q = query(
    collection(db, "products"),
    where("name", "==", name),
    where("category_id", "==", categoryId),
    where("is_deleted", "==", false)
  );
  const snap = await getDocs(q);

  if (!snap.empty) {
    const existingDoc = snap.docs[0];
    await updateDoc(existingDoc.ref, {
      price: price ?? existingDoc.data().price ?? 0,
      description: productDescription || existingDoc.data().description || "",
    });
    return existingDoc.id;
  }

  const newProduct = await addDoc(collection(db, "products"), {
    name,
    price: price ?? 0,
    quantity: 0,
    description: productDescription,
    category_id: categoryId,
    image: "",
    batch_no: "",
    mfg_date: null,
    exp_date: null,
    is_deleted: false,
    created_at: serverTimestamp(),
  });

  return newProduct.id;
};

/*------------------------------------------
    3. TẠO BATCH CHO PRODUCT
-------------------------------------------*/
export const addProductBatch = async (productId, batchNumber, quantity, mfgDate, expDate) => {
  if (!productId) return;

  await addDoc(collection(db, "product_batches"), {
    product_id: productId,
    batch_number: batchNumber ?? "",
    quantity: quantity ?? 0,
    mfg_date: mfgDate,       // đã là Timestamp hoặc null
    expiry_date: expDate,     // đã là Timestamp hoặc null
    created_at: serverTimestamp(),
    is_deleted: false,
  });

  await updateTotalQuantity(productId);
};

/*------------------------------------------
    4. CẬP NHẬT product.quantity = tổng batch
-------------------------------------------*/
export const updateTotalQuantity = async (productId) => {
  if (!productId) {
    console.warn("updateTotalQuantity skipped: productId is null/undefined");
    return;
  }

  const q = query(
    collection(db, "product_batches"),
    where("product_id", "==", productId),
    where("is_deleted", "==", false)
  );

  const snap = await getDocs(q);

  let total = 0;
  snap.forEach((d) => {
    total += Number(d.data().quantity ?? 0);
  });

  await updateDoc(doc(db, "products", productId), {
    quantity: total,
  });
};

/*------------------------------------------
    5. GHI import_logs
-------------------------------------------*/
export const logImportHistory = async (batches, adminInfo) => {
  // đảm bảo phone luôn có giá trị chuỗi
  const safeAdminInfo = {
    ...adminInfo,
    phone: adminInfo.phone || "",
    name: adminInfo.name || "",
    email: adminInfo.email || "",
    role: adminInfo.role || "",
    username: adminInfo.username || "",
  };

  await addDoc(collection(db, "import_logs"), {
    batches,
    admin_name: safeAdminInfo.name,
    admin_email: safeAdminInfo.email,
    admin_role: safeAdminInfo.role,
    admin_username: safeAdminInfo.username,
    admin_phone: safeAdminInfo.phone,
    created_at: serverTimestamp(),
  });
};

/*------------------------------------------
    6. HÀM CHÍNH IMPORT (GỌI KHI NHẤN NÚT IMPORT)
-------------------------------------------*/
export const importExcelData = async (excelRows, adminInfo) => {
  const importedBatchesMap = {};
  const receipt_number = `NH-${Date.now()}`; // mã phiếu nhập tự sinh

  for (const row of excelRows) {
    const {
      category_name,
      category_description,
      product_name,
      product_description,
      batch_number,
      quantity,
      price,
      mfg_date,
      exp_date,
      supplier_name,
    } = row;

    // 1) Category
    const categoryId = await findOrCreateCategory(category_name, category_description);

    // 2) Product
    const productId = await findOrCreateProduct(
      product_name,
      categoryId,
      Number(price ?? 0),
      product_description
    );

    // 3) Batch - CHUẨN HÓA NGÀY TRƯỚC KHI LƯU
    await addProductBatch(
      productId,
      batch_number,
      Number(quantity ?? 0),
      parseFlexibleDate(mfg_date),
      parseFlexibleDate(exp_date)
    );

    // 4) Lưu thông tin batch để ghi log (giữ nguyên dạng gốc để dễ đọc)
    if (!importedBatchesMap[batch_number]) {
      importedBatchesMap[batch_number] = {
        batch_number,
        products: [],
        supplier_name: supplier_name ?? "",
        receipt_number,
      };
    }

    importedBatchesMap[batch_number].products.push({
      product_id: productId,
      product_name,
      category_id: categoryId,
      category_name,
      quantity: Number(quantity ?? 0),
      price: Number(price ?? 0),
      mfg_date: mfg_date || null, // giữ nguyên để hiển thị trong log
      exp_date: exp_date || null,
      product_description,
      category_description,
    });
  }

  const importedBatches = Object.values(importedBatchesMap);

  await logImportHistory(importedBatches, adminInfo);

  return true;
};