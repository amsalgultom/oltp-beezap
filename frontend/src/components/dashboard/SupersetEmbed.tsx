"use client";

import { useEffect, useRef } from "react";
import { Loader2, AlertCircle } from "lucide-react";
import { useGuestToken } from "@/hooks/use-superset";
import { embedDashboard } from "@superset-ui/embedded-sdk";

interface SupersetEmbedProps {
  dashboardUuid: string;
  supersetUrl: string;
  className?: string;
}

export function SupersetEmbed({ dashboardUuid, supersetUrl, className }: SupersetEmbedProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { data, error, isLoading, refetch } = useGuestToken(dashboardUuid);

  useEffect(() => {
    if (!data?.token || !containerRef.current) return;

    const container = containerRef.current;
    container.innerHTML = "";

    embedDashboard({
      id: dashboardUuid,
      supersetDomain: supersetUrl,
      mountPoint: container,
      fetchGuestToken: async () => {
        // Refetch a fresh token if the SDK asks for one
        const result = await refetch();
        return result.data?.token ?? data.token;
      },
      dashboardUiConfig: {
        hideTitle: true,
        hideChartControls: false,
        filters: { expanded: true },
      },
    });

    return () => {
      container.innerHTML = "";
    };
  }, [data?.token, dashboardUuid, supersetUrl, refetch]);

  if (isLoading) {
    return (
      <div className="flex h-full items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-2 text-destructive">
        <AlertCircle className="h-8 w-8" />
        <p className="text-sm font-medium">Failed to load dashboard</p>
        <p className="text-xs text-muted-foreground">
          {error instanceof Error ? error.message : "Unknown error"}
        </p>
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      className={className}
      style={{ width: "100%", height: "100%", border: "none" }}
    />
  );
}
