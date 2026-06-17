import Link from "next/link";
import { Settings2, LayoutDashboard } from "lucide-react";
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

const SETTING_CARDS = [
  {
    title: "Superset Connection",
    description: "Configure the URL, credentials, and embedding settings for Apache Superset.",
    href: "/settings/superset",
    icon: Settings2,
  },
  {
    title: "Dashboards",
    description: "Add, reorder, and set access roles for dashboards shown in the app.",
    href: "/settings/dashboards",
    icon: LayoutDashboard,
  },
];

export default function SettingsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground">Manage application configuration.</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {SETTING_CARDS.map((card) => (
          <Link key={card.href} href={card.href}>
            <Card className="h-full cursor-pointer transition-shadow hover:shadow-md">
              <CardHeader>
                <div className="flex items-center gap-2">
                  <card.icon className="h-5 w-5 text-primary" />
                  <CardTitle className="text-base">{card.title}</CardTitle>
                </div>
                <CardDescription>{card.description}</CardDescription>
              </CardHeader>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  );
}
