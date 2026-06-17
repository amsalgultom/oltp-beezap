"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Plus, Pencil, Trash2, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { Role } from "@prisma/client";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { DashboardConfig, SupersetDashboard } from "@/types/dashboard";
import { ROLE_LABELS, ROLE_ORDER } from "@/lib/auth/rbac";

const schema = z.object({
  name: z.string().min(1),
  slug: z.string().min(1).regex(/^[a-z0-9-]+$/, "Lowercase letters, numbers, hyphens only"),
  description: z.string().optional(),
  supersetUuid: z.string().uuid("Must be a valid UUID"),
  icon: z.string().optional(),
  displayOrder: z.coerce.number().int().default(0),
  isActive: z.boolean().default(true),
  allowedRoles: z.array(z.nativeEnum(Role)).min(1, "Select at least one role"),
});

type FormValues = z.infer<typeof schema>;

export function DashboardSettingsTable() {
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<DashboardConfig | null>(null);

  const { data: dashboards = [], isLoading } = useQuery<DashboardConfig[]>({
    queryKey: ["all-dashboards"],
    queryFn: async () => {
      const res = await fetch("/api/dashboards");
      if (!res.ok) throw new Error("Failed to load");
      return res.json();
    },
  });

  const { data: supersetDashboards = [] } = useQuery<SupersetDashboard[]>({
    queryKey: ["superset-dashboards"],
    queryFn: async () => {
      const res = await fetch("/api/superset/dashboards");
      if (!res.ok) return [];
      return res.json();
    },
  });

  const { reset, register, handleSubmit, setValue, watch, formState: { errors, isSubmitting } } =
    useForm<FormValues>({ resolver: zodResolver(schema) });

  const createMutation = useMutation({
    mutationFn: (data: FormValues) =>
      fetch("/api/dashboards", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }).then((r) => r.json()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["all-dashboards"] });
      queryClient.invalidateQueries({ queryKey: ["dashboards"] });
      toast.success("Dashboard added");
      setDialogOpen(false);
    },
    onError: () => toast.error("Failed to save"),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<FormValues> }) =>
      fetch(`/api/dashboards/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }).then((r) => r.json()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["all-dashboards"] });
      queryClient.invalidateQueries({ queryKey: ["dashboards"] });
      toast.success("Dashboard updated");
      setDialogOpen(false);
    },
    onError: () => toast.error("Failed to update"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) =>
      fetch(`/api/dashboards/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["all-dashboards"] });
      queryClient.invalidateQueries({ queryKey: ["dashboards"] });
      toast.success("Dashboard removed");
    },
    onError: () => toast.error("Failed to delete"),
  });

  const openCreate = () => {
    setEditing(null);
    reset({ allowedRoles: [Role.VIEWER], isActive: true, displayOrder: 0 });
    setDialogOpen(true);
  };

  const openEdit = (d: DashboardConfig) => {
    setEditing(d);
    reset({
      name: d.name,
      slug: d.slug,
      description: d.description ?? "",
      supersetUuid: d.supersetUuid,
      icon: d.icon ?? "",
      displayOrder: d.displayOrder,
      isActive: d.isActive,
      allowedRoles: d.allowedRoles,
    });
    setDialogOpen(true);
  };

  const onSubmit = (values: FormValues) => {
    if (editing) {
      updateMutation.mutate({ id: editing.id, data: values });
    } else {
      createMutation.mutate(values);
    }
  };

  const selectedRoles = watch("allowedRoles") ?? [];
  const toggleRole = (role: Role) => {
    const current = selectedRoles;
    setValue(
      "allowedRoles",
      current.includes(role) ? current.filter((r) => r !== role) : [...current, role]
    );
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button onClick={openCreate}>
          <Plus className="mr-2 h-4 w-4" />
          Add Dashboard
        </Button>
      </div>

      {isLoading ? (
        <div className="flex h-20 items-center justify-center">
          <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
        </div>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Slug</TableHead>
              <TableHead>Superset UUID</TableHead>
              <TableHead>Roles</TableHead>
              <TableHead>Order</TableHead>
              <TableHead>Active</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {dashboards.map((d) => (
              <TableRow key={d.id}>
                <TableCell className="font-medium">{d.name}</TableCell>
                <TableCell className="font-mono text-xs">{d.slug}</TableCell>
                <TableCell className="font-mono text-xs">{d.supersetUuid.slice(0, 8)}…</TableCell>
                <TableCell>
                  <div className="flex flex-wrap gap-1">
                    {d.allowedRoles.map((r) => (
                      <Badge key={r} variant="secondary" className="text-xs">
                        {ROLE_LABELS[r]}
                      </Badge>
                    ))}
                  </div>
                </TableCell>
                <TableCell>{d.displayOrder}</TableCell>
                <TableCell>
                  <Switch
                    checked={d.isActive}
                    onCheckedChange={(v) => updateMutation.mutate({ id: d.id, data: { isActive: v } })}
                  />
                </TableCell>
                <TableCell className="text-right">
                  <div className="flex justify-end gap-1">
                    <Button variant="ghost" size="icon" onClick={() => openEdit(d)}>
                      <Pencil className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="text-destructive hover:text-destructive"
                      onClick={() => deleteMutation.mutate(d.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{editing ? "Edit Dashboard" : "Add Dashboard"}</DialogTitle>
            <DialogDescription>
              Map a Superset dashboard to this app and configure its access.
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label>Name</Label>
                <Input {...register("name")} placeholder="Revenue Overview" />
                {errors.name && <p className="text-xs text-destructive">{errors.name.message}</p>}
              </div>
              <div className="space-y-2">
                <Label>Slug</Label>
                <Input {...register("slug")} placeholder="revenue-overview" />
                {errors.slug && <p className="text-xs text-destructive">{errors.slug.message}</p>}
              </div>
              <div className="space-y-2 sm:col-span-2">
                <Label>Superset UUID</Label>
                {supersetDashboards.length > 0 ? (
                  <Select
                    onValueChange={(v) => {
                      setValue("supersetUuid", v);
                      const found = supersetDashboards.find((d) => d.uuid === v);
                      if (found && !watch("name")) setValue("name", found.title);
                    }}
                    value={watch("supersetUuid")}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select from Superset..." />
                    </SelectTrigger>
                    <SelectContent>
                      {supersetDashboards.map((d) => (
                        <SelectItem key={d.uuid} value={d.uuid}>
                          {d.title}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                ) : (
                  <Input {...register("supersetUuid")} placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" />
                )}
                {errors.supersetUuid && (
                  <p className="text-xs text-destructive">{errors.supersetUuid.message}</p>
                )}
              </div>
              <div className="space-y-2 sm:col-span-2">
                <Label>Description (optional)</Label>
                <Input {...register("description")} placeholder="Short description" />
              </div>
              <div className="space-y-2">
                <Label>Icon</Label>
                <Input {...register("icon")} placeholder="LayoutDashboard" />
              </div>
              <div className="space-y-2">
                <Label>Display Order</Label>
                <Input type="number" {...register("displayOrder")} />
              </div>
              <div className="space-y-2 sm:col-span-2">
                <Label>Allowed Roles</Label>
                <div className="flex flex-wrap gap-2">
                  {ROLE_ORDER.map((role) => (
                    <button
                      key={role}
                      type="button"
                      onClick={() => toggleRole(role)}
                      className={`rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
                        selectedRoles.includes(role)
                          ? "border-primary bg-primary text-primary-foreground"
                          : "border-input bg-background hover:bg-accent"
                      }`}
                    >
                      {ROLE_LABELS[role]}
                    </button>
                  ))}
                </div>
                {errors.allowedRoles && (
                  <p className="text-xs text-destructive">{errors.allowedRoles.message}</p>
                )}
              </div>
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" disabled={isSubmitting}>
                {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {editing ? "Update" : "Create"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
