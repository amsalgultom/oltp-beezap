import { prisma } from "@/lib/db/prisma";

interface SupersetConfig {
  url: string;
  username: string;
  password: string;
}

interface GuestTokenPayload {
  user: { username: string; first_name: string; last_name: string };
  resources: { type: "dashboard"; id: string }[];
  rls: unknown[];
}

async function getConfig(): Promise<SupersetConfig> {
  const settings = await prisma.appSetting.findMany({
    where: { key: { in: ["superset.url", "superset.username", "superset.password"] } },
  });

  const map = Object.fromEntries(settings.map((s) => [s.key, s.value]));

  const url = map["superset.url"];
  const username = map["superset.username"];
  const password = map["superset.password"];

  if (!url || !username || !password) {
    throw new Error("Superset connection not configured. Go to Settings → Superset.");
  }

  return { url, username, password };
}

async function getAccessToken(config: SupersetConfig): Promise<string> {
  const res = await fetch(`${config.url}/api/v1/security/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      username: config.username,
      password: config.password,
      provider: "db",
    }),
  });

  if (!res.ok) {
    throw new Error(`Superset login failed: ${res.status} ${res.statusText}`);
  }

  const data = await res.json();
  return data.access_token as string;
}

export async function getGuestToken(
  dashboardUuid: string,
  userInfo: { username: string; firstName: string; lastName: string }
): Promise<string> {
  const config = await getConfig();
  const accessToken = await getAccessToken(config);

  const payload: GuestTokenPayload = {
    user: {
      username: userInfo.username,
      first_name: userInfo.firstName,
      last_name: userInfo.lastName,
    },
    resources: [{ type: "dashboard", id: dashboardUuid }],
    rls: [],
  };

  const res = await fetch(`${config.url}/api/v1/security/guest_token/`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    throw new Error(`Failed to get guest token: ${res.status} ${res.statusText}`);
  }

  const data = await res.json();
  return data.token as string;
}

// Fetch all dashboards from Superset for the picker in settings
export async function listSupersetDashboards(): Promise<
  { id: number; uuid: string; title: string; status: string }[]
> {
  const config = await getConfig();
  const accessToken = await getAccessToken(config);

  const res = await fetch(
    `${config.url}/api/v1/dashboard/?q=(page_size:100,order_column:changed_on_delta_humanized,order_direction:desc)`,
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );

  if (!res.ok) throw new Error("Failed to fetch Superset dashboards");

  const data = await res.json();
  return (data.result as { id: number; uuid: string; dashboard_title: string; status: string }[]).map(
    (d) => ({ id: d.id, uuid: d.uuid, title: d.dashboard_title, status: d.status })
  );
}

export async function getSupersetUrl(): Promise<string> {
  const setting = await prisma.appSetting.findUnique({ where: { key: "superset.url" } });
  return setting?.value ?? "";
}
