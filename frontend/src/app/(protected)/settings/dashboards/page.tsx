import { DashboardSettingsTable } from "@/components/settings/DashboardSettingsTable";

export default function DashboardSettingsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Dashboards</h1>
        <p className="text-muted-foreground">
          Register Superset dashboards and configure who can see them.
        </p>
      </div>
      <DashboardSettingsTable />
    </div>
  );
}
