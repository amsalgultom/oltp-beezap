import { notFound } from "next/navigation";
import { prisma } from "@/lib/db/prisma";
import { getSupersetUrl } from "@/lib/superset/client";
import { SupersetEmbed } from "@/components/dashboard/SupersetEmbed";

interface PageProps {
  params: { id: string };
}

export default async function DashboardPage({ params }: PageProps) {
  const [dashboard, supersetUrl] = await Promise.all([
    prisma.dashboardConfig.findUnique({ where: { id: params.id } }),
    getSupersetUrl(),
  ]);

  if (!dashboard || !dashboard.isActive) notFound();

  return (
    <div className="flex h-full flex-col gap-4">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">{dashboard.name}</h1>
        {dashboard.description && (
          <p className="text-muted-foreground">{dashboard.description}</p>
        )}
      </div>
      <div className="flex-1 rounded-lg border overflow-hidden" style={{ minHeight: "600px" }}>
        <SupersetEmbed
          dashboardUuid={dashboard.supersetUuid}
          supersetUrl={supersetUrl}
          className="h-full w-full"
        />
      </div>
    </div>
  );
}
