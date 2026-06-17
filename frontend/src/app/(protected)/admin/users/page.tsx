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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ROLE_LABELS, ROLE_ORDER } from "@/lib/auth/rbac";
import { useAuth } from "@/hooks/use-auth";
import { Switch } from "@/components/ui/switch";

interface User {
  id: string;
  email: string;
  name: string;
  role: Role;
  isActive: boolean;
  createdAt: string;
}

const createSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
  password: z.string().min(8),
  role: z.nativeEnum(Role),
});

const editSchema = z.object({
  name: z.string().min(1),
  role: z.nativeEnum(Role),
  isActive: z.boolean(),
  password: z.string().min(8).optional().or(z.literal("")),
});

type CreateValues = z.infer<typeof createSchema>;
type EditValues = z.infer<typeof editSchema>;

export default function UsersPage() {
  const queryClient = useQueryClient();
  const { user: currentUser } = useAuth();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);

  const { data: users = [], isLoading } = useQuery<User[]>({
    queryKey: ["users"],
    queryFn: async () => {
      const res = await fetch("/api/users");
      if (!res.ok) throw new Error("Failed");
      return res.json();
    },
  });

  const createForm = useForm<CreateValues>({ resolver: zodResolver(createSchema) });
  const editForm = useForm<EditValues>({ resolver: zodResolver(editSchema) });

  const createMutation = useMutation({
    mutationFn: (data: CreateValues) =>
      fetch("/api/users", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }).then(async (r) => {
        if (!r.ok) throw new Error((await r.json()).error);
        return r.json();
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
      toast.success("User created");
      setDialogOpen(false);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<EditValues> }) =>
      fetch(`/api/users/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }).then((r) => r.json()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
      toast.success("User updated");
      setDialogOpen(false);
    },
    onError: () => toast.error("Failed to update"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => fetch(`/api/users/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
      toast.success("User deleted");
    },
    onError: () => toast.error("Failed to delete"),
  });

  const openCreate = () => {
    setEditingUser(null);
    createForm.reset({ role: Role.VIEWER });
    setDialogOpen(true);
  };

  const openEdit = (u: User) => {
    setEditingUser(u);
    editForm.reset({ name: u.name, role: u.role, isActive: u.isActive, password: "" });
    setDialogOpen(true);
  };

  const ROLE_BADGE_VARIANT: Record<Role, "default" | "secondary" | "outline" | "warning"> = {
    SUPER_ADMIN: "default",
    ADMIN: "secondary",
    ANALYST: "outline",
    VIEWER: "outline",
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Users</h1>
          <p className="text-muted-foreground">Manage user accounts and roles.</p>
        </div>
        <Button onClick={openCreate}>
          <Plus className="mr-2 h-4 w-4" />
          Add User
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
              <TableHead>Email</TableHead>
              <TableHead>Role</TableHead>
              <TableHead>Active</TableHead>
              <TableHead>Joined</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {users.map((u) => (
              <TableRow key={u.id}>
                <TableCell className="font-medium">{u.name}</TableCell>
                <TableCell>{u.email}</TableCell>
                <TableCell>
                  <Badge variant={ROLE_BADGE_VARIANT[u.role]}>{ROLE_LABELS[u.role]}</Badge>
                </TableCell>
                <TableCell>
                  <Switch
                    checked={u.isActive}
                    disabled={u.id === currentUser?.id}
                    onCheckedChange={(v) =>
                      updateMutation.mutate({ id: u.id, data: { isActive: v } })
                    }
                  />
                </TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {new Date(u.createdAt).toLocaleDateString()}
                </TableCell>
                <TableCell className="text-right">
                  <div className="flex justify-end gap-1">
                    <Button variant="ghost" size="icon" onClick={() => openEdit(u)}>
                      <Pencil className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="text-destructive hover:text-destructive"
                      disabled={u.id === currentUser?.id}
                      onClick={() => deleteMutation.mutate(u.id)}
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

      {/* Create Dialog */}
      <Dialog open={dialogOpen && !editingUser} onOpenChange={(o) => { if (!o) setDialogOpen(false); }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create User</DialogTitle>
            <DialogDescription>Add a new user to the system.</DialogDescription>
          </DialogHeader>
          <form onSubmit={createForm.handleSubmit((v) => createMutation.mutate(v))} className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label>Name</Label>
                <Input {...createForm.register("name")} />
                {createForm.formState.errors.name && (
                  <p className="text-xs text-destructive">{createForm.formState.errors.name.message}</p>
                )}
              </div>
              <div className="space-y-2">
                <Label>Email</Label>
                <Input type="email" {...createForm.register("email")} />
              </div>
              <div className="space-y-2">
                <Label>Password</Label>
                <Input type="password" {...createForm.register("password")} />
                {createForm.formState.errors.password && (
                  <p className="text-xs text-destructive">{createForm.formState.errors.password.message}</p>
                )}
              </div>
              <div className="space-y-2">
                <Label>Role</Label>
                <Select
                  value={createForm.watch("role")}
                  onValueChange={(v) => createForm.setValue("role", v as Role)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {ROLE_ORDER.map((r) => (
                      <SelectItem key={r} value={r}>{ROLE_LABELS[r]}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>Cancel</Button>
              <Button type="submit" disabled={createForm.formState.isSubmitting}>
                {createForm.formState.isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                Create
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Edit Dialog */}
      <Dialog open={dialogOpen && !!editingUser} onOpenChange={(o) => { if (!o) setDialogOpen(false); }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit User</DialogTitle>
            <DialogDescription>Update {editingUser?.name}'s account.</DialogDescription>
          </DialogHeader>
          <form onSubmit={editForm.handleSubmit((v) => {
            if (!editingUser) return;
            const data: Partial<EditValues> = { name: v.name, role: v.role, isActive: v.isActive };
            if (v.password) data.password = v.password;
            updateMutation.mutate({ id: editingUser.id, data });
          })} className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2 sm:col-span-2">
                <Label>Name</Label>
                <Input {...editForm.register("name")} />
              </div>
              <div className="space-y-2">
                <Label>Role</Label>
                <Select value={editForm.watch("role")} onValueChange={(v) => editForm.setValue("role", v as Role)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {ROLE_ORDER.map((r) => (
                      <SelectItem key={r} value={r}>{ROLE_LABELS[r]}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>New Password (optional)</Label>
                <Input type="password" placeholder="Leave blank to keep" {...editForm.register("password")} />
              </div>
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>Cancel</Button>
              <Button type="submit" disabled={editForm.formState.isSubmitting}>
                {editForm.formState.isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                Save
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
