import { getUserSession } from "./services/authService";
import { Navigate } from "react-router-dom";

export default function PrivateRoute({ children }) {
  const user = getUserSession();
  return user ? children : <Navigate to="/login" />;
}
