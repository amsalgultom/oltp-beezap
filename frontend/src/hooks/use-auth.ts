"use client";

import { useSession } from "next-auth/react";
import { hasPermission, type Permission } from "@/lib/auth/rbac";
import { Role } from "@prisma/client";

export function useAuth() {
  const { data: session, status } = useSession();

  const can = (permission: Permission): boolean => {
    if (!session?.user?.role) return false;
    return hasPermission(session.user.role as Role, permission);
  };

  return {
    user: session?.user,
    role: session?.user?.role,
    isLoading: status === "loading",
    isAuthenticated: status === "authenticated",
    can,
  };
}
