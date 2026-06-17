import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth/config";
import { hasPermission } from "@/lib/auth/rbac";
import { prisma } from "@/lib/db/prisma";
import { Role } from "@prisma/client";
import { z } from "zod";

const SENSITIVE_KEYS = ["superset.password"];

const updateSchema = z.record(z.string(), z.string());

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "settings:view")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const settings = await prisma.appSetting.findMany();
  const masked = Object.fromEntries(
    settings.map((s) => [
      s.key,
      SENSITIVE_KEYS.includes(s.key) ? (s.value ? "**REDACTED**" : "") : s.value,
    ])
  );

  return NextResponse.json(masked);
}

export async function PUT(req: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "settings:manage")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const body = await req.json();
  const parsed = updateSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid payload" }, { status: 400 });
  }

  await Promise.all(
    Object.entries(parsed.data).map(([key, value]) => {
      // Skip redacted sentinel — don't overwrite existing password with "**REDACTED**"
      if (SENSITIVE_KEYS.includes(key) && value === "**REDACTED**") return;
      return prisma.appSetting.upsert({
        where: { key },
        update: { value },
        create: { key, value },
      });
    })
  );

  return NextResponse.json({ ok: true });
}
