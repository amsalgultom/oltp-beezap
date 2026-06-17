import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth/config";
import { hasPermission } from "@/lib/auth/rbac";
import { prisma } from "@/lib/db/prisma";
import { Role } from "@prisma/client";
import bcrypt from "bcryptjs";
import { z } from "zod";

const updateSchema = z.object({
  name: z.string().min(1).optional(),
  role: z.nativeEnum(Role).optional(),
  isActive: z.boolean().optional(),
  password: z.string().min(8).optional(),
});

type Params = { params: { id: string } };

export async function PUT(req: NextRequest, { params }: Params) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "users:manage")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const body = await req.json();
  const parsed = updateSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const { password, ...rest } = parsed.data;
  const data: typeof rest & { passwordHash?: string } = { ...rest };
  if (password) data.passwordHash = await bcrypt.hash(password, 12);

  const user = await prisma.user.update({
    where: { id: params.id },
    data,
    select: { id: true, email: true, name: true, role: true, isActive: true, createdAt: true },
  });

  return NextResponse.json(user);
}

export async function DELETE(_req: NextRequest, { params }: Params) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "users:manage")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  // Prevent self-deletion
  if (params.id === session.user.id) {
    return NextResponse.json({ error: "Cannot delete your own account" }, { status: 400 });
  }

  await prisma.user.delete({ where: { id: params.id } });
  return new NextResponse(null, { status: 204 });
}
