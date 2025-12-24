// admin_web/src/firebase.js

import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyCrXMXeT1i1edB4rAPt7ym1mKf0fYHnZ44",
  appId: "1:1008688867428:web:d6911fea724e812b8c5771",
  messagingSenderId: "1008688867428",
  projectId: "app-qlkth-nhom8",
  authDomain: "app-qlkth-nhom8.firebaseapp.com",
  storageBucket: "app-qlkth-nhom8.firebasestorage.app",
  measurementId: "G-HQKBFZ7JLE",
};

// Khởi tạo app
const app = initializeApp(firebaseConfig);

// Firestore + Storage
export const db = getFirestore(app);
export const storage = getStorage(app);
export const auth = getAuth(app);
