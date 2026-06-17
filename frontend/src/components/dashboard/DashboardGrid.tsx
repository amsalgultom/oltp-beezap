"use client";

import { Loader2 } from "lucide-react";
import { useDashboards } from "@/hooks/use-superset";
import { DashboardCard } from "./DashboardCard";

export function DashboardGrid() {
  const { data: dashboards, isLoading, error } = useDashboards();

  if (isLoading) {
    return (
      <div className="flex h-40 items-center justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (error) {
    return (
      <p className="text-sm text-destructive">
        Failed to load dashboards. Please try again.
      </p>
    );
  }

  if (!dashboards?.length) {
    return (
      <p className="text-sm text-muted-foreground">
        No dashboards available. Ask an admin to add one in Settings → Dashboards.
      </p>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {dashboards.map((d) => (
        <DashboardCard key={d.id} dashboard={d} />
      ))}
    </div>
  );
}
