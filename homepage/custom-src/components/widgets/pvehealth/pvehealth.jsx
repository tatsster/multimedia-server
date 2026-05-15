import { useTranslation } from "next-i18next";
import { FaRegClock, FaThermometerHalf } from "react-icons/fa";
import useSWR from "swr";

import Container from "../widget/container";
import Error from "../widget/error";
import Raw from "../widget/raw";
import Resource from "../widget/resource";
import WidgetLabel from "../widget/widget_label";

function formatUptime(seconds, fallback) {
  if (!seconds && fallback) return fallback;
  if (!seconds) return "-";
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}m`;
}

function tempStatus(temp, warn = 70, crit = 85) {
  if (!temp) return "-";
  if (temp >= crit) return "Crit";
  if (temp >= warn) return "Warn";
  return "OK";
}

export default function PveHealth({ options }) {
  const { t } = useTranslation();
  const refresh = Math.max(options.refresh ?? 30000, 5000);
  const systemId = options.systemId ?? "proxmox";
  const tempMax = options.tempmax ?? 90;
  const tempWarn = options.tempwarn ?? 70;
  const tempCrit = options.tempcrit ?? 85;

  const { data, error } = useSWR(`/api/widgets/pvehealth?${new URLSearchParams({ systemId }).toString()}`, {
    refreshInterval: refresh,
  });

  if (error || data?.error) return <Error options={options} />;

  const temp = data?.temperature_c;
  const maxTemp = data?.temperature_max_c;
  const tempPercent = temp ? Math.min(100, Math.max(0, Math.round((temp / tempMax) * 100))) : 0;
  const uptimePercent = Math.round((new Date().getSeconds() / 60) * 100).toString();
  const unit = "celsius";

  return (
    <Container options={options} additionalClassNames="information-widget-pvehealth">
      <Raw>
        <div className="flex flex-row self-center flex-wrap justify-between">
          <Resource
            icon={FaThermometerHalf}
            value={
              temp
                ? t("common.number", {
                    value: temp,
                    maximumFractionDigits: 0,
                    style: "unit",
                    unit,
                  })
                : "-"
            }
            label="TEMP"
            expandedValue={
              maxTemp
                ? t("common.number", {
                    value: maxTemp,
                    maximumFractionDigits: 0,
                    style: "unit",
                    unit,
                  })
                : tempStatus(temp, tempWarn, tempCrit)
            }
            expandedLabel={maxTemp ? tempStatus(temp, tempWarn, tempCrit) : ""}
            percentage={tempPercent}
            expanded
          />
          <Resource
            icon={FaRegClock}
            value={formatUptime(data?.uptime_seconds, data?.uptime)}
            label="UP"
            percentage={uptimePercent}
          />
        </div>
        {options.label && <WidgetLabel label={options.label} />}
      </Raw>
    </Container>
  );
}
