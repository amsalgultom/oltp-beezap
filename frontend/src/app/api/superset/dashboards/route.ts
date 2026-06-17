import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth/config";
import { hasPermission } from "@/lib/auth/rbac";
import { listSupersetDashboards } from "@/lib/superset/client";
import { Role } from "@prisma/client";

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasPermission(session.user.role as Role, "dashboard:manage")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  try {
    const dashboards = await listSupersetDashboards();
    return NextResponse.json(dashboards);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
