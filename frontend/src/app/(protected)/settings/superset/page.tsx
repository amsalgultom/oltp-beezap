import { SupersetConfigForm } from "@/components/settings/SupersetConfigForm";

export default function SupersetSettingsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Superset Connection</h1>
        <p className="text-muted-foreground">
          Connect this app to your Apache Superset instance.
        </p>
      </div>
      <SupersetConfigForm />
    </div>
  );
}
