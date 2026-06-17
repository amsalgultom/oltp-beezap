import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth/config";
import { hasPermission } from "@/lib/auth/rbac";
import { prisma } from "@/lib/db/prisma";
import { Role } from "@prisma/client";
import { z } from "zod";

const createSchema = z.object({
  name: z.string().min(1),
  slug: z.string().min(1).regex(/^[a-z0-9-]+$/),
  description: z.string().optional(),
  supersetUuid: z.string().uuid(),
  icon: z.string().optional(),
  displayOrder: z.number().int().default(0),
  allowedRoles: z.array(z.nativeEnum(Role)).default([Role.VIEWER]),
});

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const role = session.user.role as Role;

  const dashboards = await prisma.dashboardConfig.findMany({
    where: {
      isActive: true,
      allowedRoles: { has: role },
    },
    orderBy: { displayOrder: "asc" },
  });

  return NextResponse.json(dashboards);
}

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "dashboard:manage")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const body = await req.json();
  const parsed = createSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const dashboard = await prisma.dashboardConfig.create({ data: parsed.data });
  return NextResponse.json(dashboard, { status: 201 });
}
