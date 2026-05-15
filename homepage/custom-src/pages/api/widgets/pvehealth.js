async function beszelRequest(path, token) {
  const baseUrl = (process.env.HOMEPAGE_VAR_BESZEL_URL || "").replace(/\/$/, "");
  if (!baseUrl) throw new Error("Missing HOMEPAGE_VAR_BESZEL_URL");

  const response = await fetch(`${baseUrl}${path}`, {
    headers: token
      ? {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        }
      : { "Content-Type": "application/json" },
  });

  if (!response.ok) {
    throw new Error(`Beszel API ${response.status} for ${path}`);
  }

  return response.json();
}

async function beszelLogin() {
  const baseUrl = (process.env.HOMEPAGE_VAR_BESZEL_URL || "").replace(/\/$/, "");
  const identity = process.env.HOMEPAGE_VAR_BESZEL_USERNAME;
  const password = process.env.HOMEPAGE_VAR_BESZEL_PASSWORD;

  if (!baseUrl || !identity || !password) {
    throw new Error("Missing Beszel Homepage environment variables");
  }

  const response = await fetch(`${baseUrl}/api/collections/_superusers/auth-with-password`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identity, password }),
  });

  if (!response.ok) {
    throw new Error(`Beszel login failed with ${response.status}`);
  }

  const data = await response.json();
  return data.token;
}

function findSystem(systems, systemId) {
  return systems.items?.find((item) => item.id === systemId || item.name === systemId || item.host === systemId);
}

function parseAlertValue(alerts, systemId, names) {
  const wanted = names.map((name) => name.toLowerCase());
  const alert = alerts.items?.find(
    (item) => item.system === systemId && wanted.includes(String(item.name || "").toLowerCase())
  );
  return alert?.value;
}

function pickTemperature(stats) {
  const temps = stats?.items?.[0]?.stats?.t;
  if (!temps || typeof temps !== "object") return null;

  const preferredKeys = [
    "coretemp_package_id_0",
    "x86_pkg_temp",
    "cpu_package",
    "package_id_0",
  ];

  for (const key of preferredKeys) {
    const value = Number(temps[key]);
    if (Number.isFinite(value) && value > 0) return value;
  }

  const coretemp = Object.entries(temps)
    .filter(([key]) => key.startsWith("coretemp_"))
    .map(([, value]) => Number(value))
    .filter((value) => Number.isFinite(value) && value > 0);
  if (coretemp.length) return Math.max(...coretemp);

  const allTemps = Object.values(temps)
    .map((value) => Number(value))
    .filter((value) => Number.isFinite(value) && value > 0);
  return allTemps.length ? Math.max(...allTemps) : null;
}

export default async function handler(req, res) {
  try {
    const systemId = req.query.systemId || process.env.HOMEPAGE_VAR_BESZEL_SYSTEM_ID || "proxmox";
    const token = await beszelLogin();

    const systems = await beszelRequest("/api/collections/systems/records?page=1&perPage=500&sort=%2Bcreated", token);
    const system = findSystem(systems, systemId);
    if (!system) {
      return res.status(404).json({ error: `Beszel system not found: ${systemId}` });
    }

    const [alerts, latestStats] = await Promise.all([
      beszelRequest(
        `/api/collections/alerts/records?page=1&perPage=200&filter=${encodeURIComponent(`system=\"${system.id}\"`)}`,
        token
      ),
      beszelRequest(
        `/api/collections/system_stats/records?page=1&perPage=1&sort=-created&filter=${encodeURIComponent(`system=\"${system.id}\"&&type=\"1m\"`)}`,
        token
      ),
    ]);

    const temperature = pickTemperature(latestStats) ?? Number(system.info?.t ?? 0);
    const uptime = Number(system.info?.u ?? 0);
    const tempLimit = Number(parseAlertValue(alerts, system.id, ["Temperature", "Temp"]) ?? 0);

    return res.status(200).json({
      source: "beszel",
      system_id: system.id,
      system_name: system.name,
      status: system.status,
      temperature_c: temperature || null,
      temperature_source: pickTemperature(latestStats) ? "system_stats.t" : "system.info.t",
      temperature_max_c: tempLimit || temperature || null,
      uptime_seconds: uptime || null,
      updated: system.updated,
    });
  } catch (e) {
    return res.status(500).json({ error: e.message || "Beszel metrics unavailable" });
  }
}
