import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth/config";
import { hasPermission } from "@/lib/auth/rbac";
import { prisma } from "@/lib/db/prisma";
import { Role } from "@prisma/client";
import { z } from "zod";

const updateSchema = z.object({
  name: z.string().min(1).optional(),
  description: z.string().optional().nullable(),
  supersetUuid: z.string().uuid().optional(),
  icon: z.string().optional().nullable(),
  displayOrder: z.number().int().optional(),
  isActive: z.boolean().optional(),
  allowedRoles: z.array(z.nativeEnum(Role)).optional(),
});

type Params = { params: { id: string } };

export async function GET(_req: NextRequest, { params }: Params) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const dashboard = await prisma.dashboardConfig.findUnique({
    where: { id: params.id },
  });

  if (!dashboard) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  const role = session.user.role as Role;
  const canManage = hasPermission(role, "dashboard:manage");
  const isAllowed = dashboard.allowedRoles.includes(role);

  if (!canManage && !isAllowed) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  return NextResponse.json(dashboard);
}

export async function PUT(req: NextRequest, { params }: Params) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "dashboard:manage")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const body = await req.json();
  const parsed = updateSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const dashboard = await prisma.dashboardConfig.update({
    where: { id: params.id },
    data: parsed.data,
  });

  return NextResponse.json(dashboard);
}

export async function DELETE(_req: NextRequest, { params }: Params) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "dashboard:manage")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  await prisma.dashboardConfig.delete({ where: { id: params.id } });
  return new NextResponse(null, { status: 204 });
}
