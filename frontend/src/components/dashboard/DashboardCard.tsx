import Link from "next/link";
import {
  LayoutDashboard,
  BarChart2,
  TrendingUp,
  Users,
  Activity,
  PieChart,
  type LucideIcon,
} from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { DashboardConfig } from "@/types/dashboard";

// Resolve icon string → Lucide component
const ICON_MAP: Record<string, LucideIcon> = {
  LayoutDashboard,
  BarChart2,
  TrendingUp,
  Users,
  Activity,
  PieChart,
};

function DashboardIcon({ name }: { name: string | null }) {
  const Icon = name ? (ICON_MAP[name] ?? LayoutDashboard) : LayoutDashboard;
  return <Icon className="h-5 w-5" />;
}

interface DashboardCardProps {
  dashboard: DashboardConfig;
}

export function DashboardCard({ dashboard }: DashboardCardProps) {
  return (
    <Link href={`/dashboard/${dashboard.id}`}>
      <Card className="h-full cursor-pointer transition-shadow hover:shadow-md">
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <div className="flex h-9 w-9 items-center justify-center rounded-md bg-primary/10 text-primary">
              <DashboardIcon name={dashboard.icon} />
            </div>
            <CardTitle className="text-base">{dashboard.name}</CardTitle>
          </div>
        </CardHeader>
        <CardContent>
          <CardDescription className="line-clamp-2">
            {dashboard.description ?? "View analytics dashboard"}
          </CardDescription>
        </CardContent>
      </Card>
    </Link>
  );
}
