import { withAuth } from "next-auth/middleware";
import { NextResponse } from "next/server";
import { ROUTE_PERMISSIONS, hasPermission } from "@/lib/auth/rbac";
import { Role } from "@prisma/client";

export default withAuth(
  function middleware(req) {
    const { pathname } = req.nextUrl;
    const token = req.nextauth.token;

    if (!token) {
      return NextResponse.redirect(new URL("/login", req.url));
    }

    const role = token.role as Role;

    // Check route-specific permissions
    for (const [route, permission] of Object.entries(ROUTE_PERMISSIONS)) {
      if (pathname.startsWith(route) && !hasPermission(role, permission)) {
        return NextResponse.redirect(new URL("/", req.url));
      }
    }

    return NextResponse.next();
  },
  {
    callbacks: {
      authorized: ({ token }) => !!token,
    },
  }
);

export const config = {
  matcher: [
    "/((?!api/auth|login|_next/static|_next/image|favicon.ico).*)",
  ],
};
