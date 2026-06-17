"use client";

import { useQuery } from "@tanstack/react-query";
import type { DashboardConfig } from "@/types/dashboard";

export function useDashboards() {
  return useQuery<DashboardConfig[]>({
    queryKey: ["dashboards"],
    queryFn: async () => {
      const res = await fetch("/api/dashboards");
      if (!res.ok) throw new Error("Failed to fetch dashboards");
      return res.json();
    },
  });
}

export function useDashboard(id: string) {
  return useQuery<DashboardConfig>({
    queryKey: ["dashboards", id],
    queryFn: async () => {
      const res = await fetch(`/api/dashboards/${id}`);
      if (!res.ok) throw new Error("Failed to fetch dashboard");
      return res.json();
    },
    enabled: !!id,
  });
}

export function useGuestToken(dashboardUuid: string | null) {
  return useQuery<{ token: string }>({
    queryKey: ["guest-token", dashboardUuid],
    queryFn: async () => {
      const res = await fetch(
        `/api/superset/guest-token?uuid=${dashboardUuid}`
      );
      if (!res.ok) throw new Error("Failed to get guest token");
      return res.json();
    },
    enabled: !!dashboardUuid,
    // Superset guest tokens expire in ~5 minutes
    staleTime: 4 * 60 * 1000,
    refetchInterval: 4 * 60 * 1000,
  });
}
