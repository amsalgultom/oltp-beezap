"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Settings,
  Users,
  ChevronLeft,
  ChevronRight,
  BarChart2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/hooks/use-auth";
import { useDashboards } from "@/hooks/use-superset";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { useState } from "react";

interface NavItem {
  label: string;
  href: string;
  icon: React.ElementType;
  permission?: Parameters<ReturnType<typeof useAuth>["can"]>[0];
}

const STATIC_NAV: NavItem[] = [
  { label: "Overview", href: "/", icon: LayoutDashboard },
  { label: "Settings", href: "/settings", icon: Settings, permission: "settings:view" },
  { label: "Users", href: "/admin/users", icon: Users, permission: "users:view" },
];

export function Sidebar() {
  const pathname = usePathname();
  const { can } = useAuth();
  const { data: dashboards } = useDashboards();
  const [collapsed, setCollapsed] = useState(false);

  const isActive = (href: string) =>
    href === "/" ? pathname === "/" : pathname.startsWith(href);

  return (
    <aside
      className={cn(
        "relative flex h-full flex-col border-r bg-sidebar transition-all duration-200",
        collapsed ? "w-16" : "w-60"
      )}
    >
      {/* Logo */}
      <div className="flex h-16 items-center border-b px-4">
        <BarChart2 className="h-6 w-6 shrink-0 text-primary" />
        {!collapsed && (
          <span className="ml-2 font-bold text-sidebar-foreground">Beezap Analytics</span>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-1 overflow-y-auto p-2">
        {/* Static nav */}
        {STATIC_NAV.filter((item) => !item.permission || can(item.permission)).map((item) => (
          <Link key={item.href} href={item.href}>
            <div
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                isActive(item.href)
                  ? "bg-sidebar-accent text-sidebar-accent-foreground"
                  : "text-sidebar-foreground hover:bg-sidebar-accent/50"
              )}
            >
              <item.icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </div>
          </Link>
        ))}

        {/* Dynamic dashboards */}
        {dashboards && dashboards.length > 0 && (
          <>
            <Separator className="my-2" />
            {!collapsed && (
              <p className="px-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Dashboards
              </p>
            )}
            {dashboards.map((d) => (
              <Link key={d.id} href={`/dashboard/${d.id}`}>
                <div
                  className={cn(
                    "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                    isActive(`/dashboard/${d.id}`)
                      ? "bg-sidebar-accent text-sidebar-accent-foreground"
                      : "text-sidebar-foreground hover:bg-sidebar-accent/50"
                  )}
                >
                  <LayoutDashboard className="h-4 w-4 shrink-0" />
                  {!collapsed && <span className="line-clamp-1">{d.name}</span>}
                </div>
              </Link>
            ))}
          </>
        )}
      </nav>

      {/* Collapse toggle */}
      <div className="border-t p-2">
        <Button
          variant="ghost"
          size="icon"
          className="w-full"
          onClick={() => setCollapsed((v) => !v)}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          {collapsed ? <ChevronRight className="h-4 w-4" /> : <ChevronLeft className="h-4 w-4" />}
        </Button>
      </div>
    </aside>
  );
}
