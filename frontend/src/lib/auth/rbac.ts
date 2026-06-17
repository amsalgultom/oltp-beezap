import { Role } from "@prisma/client";

// Permission registry — add new permissions here as the app grows
export const PERMISSIONS = {
  "dashboard:view": [Role.SUPER_ADMIN, Role.ADMIN, Role.ANALYST, Role.VIEWER],
  "dashboard:manage": [Role.SUPER_ADMIN, Role.ADMIN],
  "settings:view": [Role.SUPER_ADMIN, Role.ADMIN],
  "settings:manage": [Role.SUPER_ADMIN],
  "users:view": [Role.SUPER_ADMIN, Role.ADMIN],
  "users:manage": [Role.SUPER_ADMIN],
} as const;

export type Permission = keyof typeof PERMISSIONS;

export function hasPermission(role: Role, permission: Permission): boolean {
  return (PERMISSIONS[permission] as readonly Role[]).includes(role);
}

export function hasAnyPermission(role: Role, permissions: Permission[]): boolean {
  return permissions.some((p) => hasPermission(role, p));
}

// Route-level access map used by middleware
export const ROUTE_PERMISSIONS: Record<string, Permission> = {
  "/settings": "settings:view",
  "/settings/superset": "settings:manage",
  "/settings/dashboards": "dashboard:manage",
  "/admin": "users:view",
  "/admin/users": "users:manage",
};

export const ROLE_LABELS: Record<Role, string> = {
  SUPER_ADMIN: "Super Admin",
  ADMIN: "Admin",
  ANALYST: "Analyst",
  VIEWER: "Viewer",
};

export const ROLE_ORDER: Role[] = [
  Role.SUPER_ADMIN,
  Role.ADMIN,
  Role.ANALYST,
  Role.VIEWER,
];
