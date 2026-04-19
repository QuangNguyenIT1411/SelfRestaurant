import type { ReactNode } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";

export function RequireAuth({ children, requireTable = false }: { children: ReactNode; requireTable?: boolean }) {
  const location = useLocation();
  const { data, isLoading } = useQuery({ queryKey: ["session"], queryFn: api.getSession });
  const from = `${location.pathname}${location.search}`;

  if (isLoading) return <div className="screen-message">Đang tải phiên làm việc...</div>;
  if (!data?.authenticated) return <Navigate to={`/Customer/Login?returnUrl=${encodeURIComponent(from)}`} replace state={{ from }} />;
  if (requireTable && !data.tableContext) return <Navigate to="/Home/Index" replace />;
  return <>{children}</>;
}
