import { PrismaClient, Role } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  // Seed super admin
  const passwordHash = await bcrypt.hash("admin123", 12);
  await prisma.user.upsert({
    where: { email: "admin@beezap.com" },
    update: {},
    create: {
      email: "admin@beezap.com",
      name: "Super Admin",
      passwordHash,
      role: Role.SUPER_ADMIN,
    },
  });

  // Seed default Superset connection settings (placeholders — override via UI)
  const defaultSettings = [
    { key: "superset.url", value: "http://localhost:8088" },
    { key: "superset.username", value: "admin" },
    { key: "superset.password", value: "" },
    { key: "superset.embed.enabled", value: "true" },
  ];

  for (const setting of defaultSettings) {
    await prisma.appSetting.upsert({
      where: { key: setting.key },
      update: {},
      create: setting,
    });
  }

  // Seed a sample dashboard config
  await prisma.dashboardConfig.upsert({
    where: { slug: "overview" },
    update: {},
    create: {
      name: "Overview",
      slug: "overview",
      description: "Main analytics overview dashboard",
      supersetUuid: "replace-with-real-superset-uuid",
      icon: "LayoutDashboard",
      displayOrder: 1,
      allowedRoles: [Role.SUPER_ADMIN, Role.ADMIN, Role.ANALYST, Role.VIEWER],
    },
  });

  console.log("Seed completed");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
