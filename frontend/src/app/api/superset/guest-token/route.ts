import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth/config";
import { getGuestToken } from "@/lib/superset/client";

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const uuid = req.nextUrl.searchParams.get("uuid");
  if (!uuid) {
    return NextResponse.json({ error: "uuid is required" }, { status: 400 });
  }

  try {
    const nameParts = session.user.name.split(" ");
    const token = await getGuestToken(uuid, {
      username: session.user.email,
      firstName: nameParts[0] ?? session.user.name,
      lastName: nameParts.slice(1).join(" ") || "-",
    });

    return NextResponse.json({ token });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
