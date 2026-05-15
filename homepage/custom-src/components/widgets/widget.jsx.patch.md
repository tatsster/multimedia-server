# Register the custom `pvehealth` information widget

Apply this one-line change to `/opt/homepage/src/components/widgets/widget.jsx` after installing/updating Homepage source.

```diff
 const widgetMappings = {
   weatherapi: dynamic(() => import("components/widgets/weather/weather")),
   openweathermap: dynamic(() => import("components/widgets/openweathermap/weather")),
   resources: dynamic(() => import("components/widgets/resources/resources")),
   search: dynamic(() => import("components/widgets/search/search")),
   greeting: dynamic(() => import("components/widgets/greeting/greeting")),
   datetime: dynamic(() => import("components/widgets/datetime/datetime")),
   logo: dynamic(() => import("components/widgets/logo/logo"), { ssr: false }),
   unifi_console: dynamic(() => import("components/widgets/unifi_console/unifi_console")),
   glances: dynamic(() => import("components/widgets/glances/glances")),
+  pvehealth: dynamic(() => import("components/widgets/pvehealth/pvehealth")),
   openmeteo: dynamic(() => import("components/widgets/openmeteo/openmeteo")),
   longhorn: dynamic(() => import("components/widgets/longhorn/longhorn")),
   kubernetes: dynamic(() => import("components/widgets/kubernetes/kubernetes")),
   stocks: dynamic(() => import("components/widgets/stocks/stocks")),
 };
```
