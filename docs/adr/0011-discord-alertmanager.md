# Architecture Decision Record (ADR)


# ADR 0011: Use Discord for Alertmanager Notifications

## Status

Accepted

## Context

The observability stack includes Alertmanager (part of `kube-prometheus-stack`) which fires alerts
when PrometheusRules are triggered, for example when nodes go `NotReady` or pods get stuck `Pending`
during the AWS FIS chaos demo. Alertmanager needs a notification channel to send these alerts to the
team in real time.

Key requirements:
* The team must receive alerts without needing to watch dashboards — push notifications on a channel the
  team already uses for communication.
* Setup must be simple: no new accounts, no paid tier, and no external services beyond what the team
  already has access to.
* Alertmanager must be able to deliver the alert payload in a format the notification target understands.

## Options Considered

### Option 1: Email

**Pros**

* Natively supported by Alertmanager (`emailConfigs`).
* No third-party accounts needed beyond an SMTP relay.

**Cons**

* Email is slower and less visible than a chat channel for a team actively monitoring a live demo.
* Requires setting up an SMTP relay with credentials, adding operational complexity.
* Not how the team communicates day-to-day during the capstone.

### Option 2: PagerDuty or OpsGenie

**Pros**

* Purpose-built for alert routing with on-call scheduling, escalations, and acknowledgement tracking.

**Cons**

* Paid tiers are required for the features that would make these tools worthwhile.
* Over-engineered for a five-person capstone team with a single shared alerting channel.

### Option 3: Slack

**Pros**

* Alertmanager has native `slackConfigs` support.
* Real-time, visible in a channel the team monitors.

**Cons**

* Slack's free tier limits message history; an Incoming Webhooks app requires workspace admin approval.
* The team does not have a Slack workspace set up for this project.

### Option 4: Discord via Slack-Compatible Webhook (Chosen)

**Pros**

* The team already uses Discord for day-to-day capstone communication — no new platform to adopt.
* Discord exposes a Slack-compatible webhook endpoint (`/slack` suffix on the webhook URL) that accepts
  the same payload format as Slack's Incoming Webhooks.
* Alertmanager's existing `slackConfigs` receiver works with the Discord Slack-compatible URL without
  any custom code or additional plugins.
* Free, no admin approval required, webhook takes seconds to create from the Discord channel settings.

**Cons**

* The Slack-compatible endpoint is a quirk of Discord's API, not a first-class integration — if Discord
  deprecates the `/slack` endpoint, the integration breaks without warning.
* Alert formatting is limited to what Alertmanager's Slack template produces; Discord's richer message
  embed format is not used.

## Decision

The team chose Discord as the notification target, using Alertmanager's `slackConfigs` receiver with
the Discord Slack-compatible webhook URL.

**Configuration details:**

* A webhook is created in the target Discord channel (Discord channel settings → Integrations →
  Webhooks → Copy Webhook URL), then `/slack` is appended to the URL to enable Slack-compatible mode.
* The webhook URL is stored as a Kubernetes Secret in the `monitoring` namespace and referenced in
  the Alertmanager configuration (in the `kube-prometheus-stack` Helm values).
* Alertmanager is configured with a `slackConfigs` receiver pointing to the Discord webhook URL.
  The `release: prometheus` label on `PrometheusRule` resources ensures kube-prometheus-stack's
  Prometheus selects those rules (see [[0004-observability-stack]]).

## Consequences

### Makes Easier

* The team sees alerts in the same Discord server they already use, with no context switch.
* No new accounts, no paid tiers, and minimal configuration beyond creating a webhook in Discord.

### Rules Out

* Rich Discord embed formatting for alert messages — only Slack-template formatting is available via
  the compatibility endpoint.
* Reliable long-term support if Discord drops the `/slack` compatibility endpoint.
