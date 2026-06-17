"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Loader2, Save, TestTube } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";

const schema = z.object({
  "superset.url": z.string().url("Must be a valid URL"),
  "superset.username": z.string().min(1, "Required"),
  "superset.password": z.string(),
  "superset.embed.enabled": z.boolean(),
});

type FormValues = z.infer<typeof schema>;

export function SupersetConfigForm() {
  const [isTesting, setIsTesting] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      "superset.url": "",
      "superset.username": "admin",
      "superset.password": "",
      "superset.embed.enabled": true,
    },
  });

  // Load current settings
  useEffect(() => {
    fetch("/api/settings")
      .then((r) => r.json())
      .then((data) => {
        reset({
          "superset.url": data["superset.url"] ?? "",
          "superset.username": data["superset.username"] ?? "",
          "superset.password": data["superset.password"] ?? "",
          "superset.embed.enabled": data["superset.embed.enabled"] === "true",
        });
      })
      .catch(() => setLoadError("Failed to load settings"));
  }, [reset]);

  const onSubmit = async (values: FormValues) => {
    const payload = {
      "superset.url": values["superset.url"],
      "superset.username": values["superset.username"],
      "superset.password": values["superset.password"],
      "superset.embed.enabled": values["superset.embed.enabled"] ? "true" : "false",
    };

    const res = await fetch("/api/settings", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (res.ok) {
      toast.success("Settings saved");
    } else {
      toast.error("Failed to save settings");
    }
  };

  const testConnection = async () => {
    setIsTesting(true);
    try {
      const res = await fetch("/api/superset/dashboards");
      if (res.ok) {
        const data = await res.json();
        toast.success(`Connected! Found ${data.length} dashboard(s) in Superset.`);
      } else {
        const err = await res.json();
        toast.error(err.error ?? "Connection failed");
      }
    } catch {
      toast.error("Connection failed");
    } finally {
      setIsTesting(false);
    }
  };

  if (loadError) {
    return <p className="text-sm text-destructive">{loadError}</p>;
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Superset Connection</CardTitle>
        <CardDescription>
          Configure how this app connects to Apache Superset. The password is stored encrypted at
          rest and never returned to the browser.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="superset-url">Superset URL</Label>
              <Input
                id="superset-url"
                placeholder="http://localhost:8088"
                {...register("superset.url")}
              />
              {errors["superset.url"] && (
                <p className="text-xs text-destructive">{errors["superset.url"].message}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="superset-user">Username</Label>
              <Input id="superset-user" {...register("superset.username")} />
            </div>

            <div className="space-y-2">
              <Label htmlFor="superset-pass">Password</Label>
              <Input
                id="superset-pass"
                type="password"
                placeholder="Leave blank to keep existing"
                {...register("superset.password")}
              />
            </div>

            <div className="flex items-center gap-3 sm:col-span-2">
              <Switch
                id="embed-enabled"
                checked={watch("superset.embed.enabled")}
                onCheckedChange={(v) => setValue("superset.embed.enabled", v)}
              />
              <Label htmlFor="embed-enabled">Enable embedded dashboards</Label>
            </div>
          </div>

          <div className="flex gap-2">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              <Save className="mr-2 h-4 w-4" />
              Save
            </Button>
            <Button type="button" variant="outline" onClick={testConnection} disabled={isTesting}>
              {isTesting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              <TestTube className="mr-2 h-4 w-4" />
              Test Connection
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
