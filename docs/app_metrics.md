# Application Metrics Inventory

This document summarizes application metrics currently captured through:

- ADOT OpenTelemetryCollector scrape job: kubernetes-pods
- Remote write to in-cluster Prometheus
- Queryable in Prometheus and Grafana

Validation date: 2026-06-16

## Current Scrape Health

All five application namespaces are currently healthy in Prometheus for job=kubernetes-pods (up=1):

- carts
- catalog
- checkout
- orders
- ui

## Metrics Captured Per Application

### carts (Spring Boot / JVM)

Main metric families seen:

- application\_\*
- http*server_requests_seconds*\*
- jvm\_\*
- process\_\*
- tomcat*sessions*\*
- up

Examples:

- http_server_requests_seconds_count
- jvm_memory_used_bytes
- tomcat_sessions_active_current_sessions

Unique metric names observed (last ~2h): 63

### catalog (Go / Gin)

Main metric families seen:

- gin\_\*
- go\_\*
- process\_\*
- up

Examples:

- gin_requests_total
- gin_request_duration_seconds_sum
- go_goroutines

Unique metric names observed (last ~2h): 55

### checkout (Node.js)

Main metric families seen:

- nodejs\_\*
- process\_\*
- up

Examples:

- nodejs_heap_size_used_bytes
- nodejs_eventloop_lag_p99_seconds
- process_resident_memory_bytes

Unique metric names observed (last ~2h): 38

### orders (Spring Boot / JVM + DB)

Main metric families seen:

- application\_\*
- hikaricp*connections*\*
- http*server_requests_seconds*\*
- jdbc*connections*\*
- jvm\_\*
- process\_\*
- spring*data_repository_invocations_seconds*\*
- tomcat*sessions*\*
- watch\_\*
- up

Examples:

- hikaricp_connections_active
- jdbc_connections_active
- watch_orders_total

Unique metric names observed (last ~2h): 88

### ui (Spring Boot / JVM)

Main metric families seen:

- application\_\*
- http*server_requests_seconds*\*
- jvm\_\*
- process\_\*
- up

Examples:

- http_server_requests_seconds_count
- jvm_gc_pause_seconds_sum
- process_cpu_usage

Unique metric names observed (last ~2h): 58

## Grafana Starter Queries (PromQL)

Use these directly in Grafana panels with your Prometheus datasource.

1. Scrape health by app

   up{job="kubernetes-pods",namespace=~"carts|catalog|checkout|orders|ui"}

2. HTTP request rate (Spring apps)

   sum by (namespace) (rate(http_server_requests_seconds_count{job="kubernetes-pods",namespace=~"carts|orders|ui"}[5m]))

3. HTTP p95 latency (Spring apps, if bucket metrics are present)

   histogram_quantile(0.95, sum by (le, namespace) (rate(http_server_requests_seconds_bucket{job="kubernetes-pods",namespace=~"carts|orders|ui"}[5m])))

4. Catalog request rate (Go/Gin)

   sum by (namespace) (rate(gin_requests_total{job="kubernetes-pods",namespace="catalog"}[5m]))

5. Checkout Node heap memory

   nodejs_heap_size_used_bytes{job="kubernetes-pods",namespace="checkout"}

6. JVM memory used (Spring apps)

   sum by (namespace) (jvm_memory_used_bytes{job="kubernetes-pods",namespace=~"carts|orders|ui"})

7. Orders DB pool utilization ratio

   hikaricp_connections_active{job="kubernetes-pods",namespace="orders"} / hikaricp_connections_max{job="kubernetes-pods",namespace="orders"}

## Notes

- This inventory reflects metrics present at validation time and may vary with runtime load.
- Some non-app pod scrape warnings can still appear in collector logs; these do not necessarily mean app metrics are failing.
- If a panel shows no data, verify labels first (namespace, job, pod) and then check current values with up queries.

## Grafana Dashboard Blueprint

Use this as a starting layout for one consolidated "Retail Store App Observability" dashboard.

### Recommended Dashboard Variables

1. namespace

   label_values(up{job="kubernetes-pods",namespace=~"carts|catalog|checkout|orders|ui"}, namespace)

2. pod

   label_values(up{job="kubernetes-pods",namespace="$namespace"}, pod)

3. interval (optional)

   Use Grafana built-in $\_\_rate_interval.

### Panel Group A: Service Health & Traffic

1. Panel: Target Up

- Type: Stat
- Unit: none
- Query:

  avg by (namespace) (up{job="kubernetes-pods",namespace=~"$namespace"})

- Thresholds:
  - Red: < 1
  - Green: 1

2. Panel: Request Rate (RPS, Spring services)

- Type: Time series
- Unit: req/s
- Query:

  sum by (namespace) (rate(http_server_requests_seconds_count{job="kubernetes-pods",namespace=~"$namespace"}[$\_\_rate_interval]))

- Legend: {{namespace}}

3. Panel: Request Rate (RPS, Catalog)

- Type: Time series
- Unit: req/s
- Query:

  sum by (namespace) (rate(gin_requests_total{job="kubernetes-pods",namespace=~"$namespace"}[$\_\_rate_interval]))

- Legend: {{namespace}}

### Panel Group B: Latency

1. Panel: HTTP Average Latency (Spring)

- Type: Time series
- Unit: s
- Query:

  sum by (namespace) (rate(http_server_requests_seconds_sum{job="kubernetes-pods",namespace=~"$namespace"}[$**rate_interval]))
  /
  sum by (namespace) (rate(http_server_requests_seconds_count{job="kubernetes-pods",namespace=~"$namespace"}[$**rate_interval]))

- Threshold suggestion:
  - Yellow: > 0.25
  - Red: > 0.50

2. Panel: Catalog Request Duration (Average)

- Type: Time series
- Unit: s
- Query:

  sum by (namespace) (rate(gin_request_duration_seconds_sum{job="kubernetes-pods",namespace=~"$namespace"}[$**rate_interval]))
  /
  sum by (namespace) (rate(gin_request_duration_seconds_count{job="kubernetes-pods",namespace=~"$namespace"}[$**rate_interval]))

### Panel Group C: Runtime Resource Usage

1. Panel: JVM Heap Used

- Type: Time series
- Unit: bytes (IEC)
- Query:

  sum by (namespace) (jvm_memory_used_bytes{job="kubernetes-pods",namespace=~"$namespace",area="heap"})

2. Panel: Node.js Heap Used (checkout)

- Type: Time series
- Unit: bytes (IEC)
- Query:

  nodejs_heap_size_used_bytes{job="kubernetes-pods",namespace="checkout",pod=~"$pod"}

3. Panel: Process CPU Usage (Spring apps)

- Type: Time series
- Unit: percent (0-1)
- Query:

  avg by (namespace) (process_cpu_usage{job="kubernetes-pods",namespace=~"$namespace"})

### Panel Group D: Orders Database Health

1. Panel: Hikari Active Connections

- Type: Time series
- Unit: none
- Query:

  sum by (namespace) (hikaricp_connections_active{job="kubernetes-pods",namespace="orders"})

2. Panel: Hikari Pool Utilization

- Type: Time series
- Unit: percent (0-1)
- Query:

  sum(hikaricp_connections_active{job="kubernetes-pods",namespace="orders"})
  /
  sum(hikaricp_connections_max{job="kubernetes-pods",namespace="orders"})

- Threshold suggestion:
  - Yellow: > 0.70
  - Red: > 0.90

3. Panel: JDBC Active Connections

- Type: Time series
- Unit: none
- Query:

  sum by (namespace) (jdbc_connections_active{job="kubernetes-pods",namespace="orders"})

### Panel Group E: Business KPI

1. Panel: Orders Counter

- Type: Time series
- Unit: short
- Query (choose the one your app emits consistently):

  sum(watch_orders_total{job="kubernetes-pods",namespace="orders"})

  or

  sum(watch_orderTotal{job="kubernetes-pods",namespace="orders"})

2. Panel: New Orders Rate

- Type: Time series
- Unit: ops
- Query:

  sum(rate(watch_orders_total{job="kubernetes-pods",namespace="orders"}[$__rate_interval]))

### Suggested Dashboard Rows

1. Row 1: Availability and traffic
2. Row 2: Latency
3. Row 3: Runtime health (JVM/Node/process)
4. Row 4: Orders DB
5. Row 5: Business KPI

### Alert Rules (Optional First Pass)

1. App target down

- Expr: min by (namespace) (up{job="kubernetes-pods",namespace=~"carts|catalog|checkout|orders|ui"}) < 1
- For: 5m

2. Orders DB pool near saturation

- Expr: (sum(hikaricp_connections_active{namespace="orders"}) / sum(hikaricp_connections_max{namespace="orders"})) > 0.9
- For: 10m

3. High Spring latency

- Expr: (sum(rate(http_server_requests_seconds_sum{namespace=~"carts|orders|ui"}[5m])) / sum(rate(http_server_requests_seconds_count{namespace=~"carts|orders|ui"}[5m]))) > 0.5
- For: 10m

## Importable Grafana Dashboard JSON

Dashboard file:

- [grafana/retail_store_app.json](grafana/retail_store_app.json)

Import steps:

1. In Grafana, go to Dashboards -> New -> Import.
2. Upload [grafana/retail_store_app.json](grafana/retail_store_app.json).
3. Select your Prometheus datasource when prompted.
4. Click Import.

Post-import quick checks:

1. Set namespace variable to All.
2. Verify "Target Up" shows green values (1) for app namespaces.
3. Confirm traffic panels populate (Spring or Gin depending on selected namespace).
