import { Role } from "@prisma/client";

export interface DashboardConfig {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  supersetUuid: string;
  icon: string | null;
  displayOrder: number;
  isActive: boolean;
  allowedRoles: Role[];
  createdAt: string;
  updatedAt: string;
}

export interface SupersetDashboard {
  id: number;
  uuid: string;
  title: string;
  status: string;
}

export interface AppSettings {
  "superset.url": string;
  "superset.username": string;
  "superset.password": string;
  "superset.embed.enabled": string;
}

export type SettingKey = keyof AppSettings;
