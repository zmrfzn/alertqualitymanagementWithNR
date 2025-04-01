# Terraform configuration
terraform {
  // required_version = "1.5.1"
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = ">=3.60.0"
    }
  }
}

# New Relic provider
provider "newrelic" {
  account_id = var.account_id
  api_key = var.api_key   # usually prefixed with 'NRAK'
  region = var.region     # Valid regions are US and EU
}

# Data source for New Relic entity
data "newrelic_entity" "hostname" {
  name = var.hostname # Note: This must be an exact match of your entity in New Relic (Case sensitive)
  type = "HOST"
  domain = "INFRA"
}

### Alert policy & condition ###

# Alert policy
resource "newrelic_alert_policy" "alert_policy_name" {
  name = "Challenge 1 - Examples for Alert Storm"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

# NRQL alert condition - High CPU
resource "newrelic_nrql_alert_condition" "highcpu" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "High CPU"
  description                    = "Alert when CPU usage is high"
  runbook_url                    = "https://www.example.com"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.infra.host.cpuUsage) FROM Metric WHERE entity.name = '${data.newrelic_entity.hostname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 50
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 30
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - High Mem
resource "newrelic_nrql_alert_condition" "highmem" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "High Mem"
  description                    = "Alert when Mem usage is high"
  runbook_url                    = "https://www.example.com"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.infra.host.memoryUsage) FROM Metric WHERE entity.name = '${data.newrelic_entity.hostname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 40
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 20
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - High Storage
resource "newrelic_nrql_alert_condition" "highstorage" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "High Storage"
  description                    = "Alert when Storage usage is high"
  runbook_url                    = "https://www.example.com"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.infra.host.storageUsage) FROM Metric WHERE entity.name = '${data.newrelic_entity.hostname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 20
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 10
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - High Network Tx
resource "newrelic_nrql_alert_condition" "highnettx" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "High Network Transfer"
  description                    = "Alert when network transfer usage is high"
  runbook_url                    = "https://www.example.com"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.infra.host.networkTrafficTx) FROM Metric WHERE entity.name = '${data.newrelic_entity.hostname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 300
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 150
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - High Network Rx
resource "newrelic_nrql_alert_condition" "highnetrx" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "High Network Receive"
  description                    = "Alert when network receive usage is high"
  runbook_url                    = "https://www.example.com"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.infra.host.networkTrafficRx) FROM Metric WHERE entity.name = '${data.newrelic_entity.hostname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 300
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 120
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - High Process Usage
resource "newrelic_nrql_alert_condition" "highprocess" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "High Process Usage"
  description                    = "Alert when process usage is high"
  runbook_url                    = "https://www.example.com"
  enabled                        = false
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 60

  nrql {
    query             = "SELECT average(host.process.cpuPercent) FROM Metric FACET processId, processDisplayName WHERE entity.name = '${data.newrelic_entity.hostname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 0.5
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 0.2
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
}

### Alert workflows & notification ###

# Notification channel
resource "newrelic_notification_destination" "c1_notification_destination" {
  name = "Alerts to Support Team"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.email
  }
}

resource "newrelic_notification_channel" "c1_notification_channel" {
  name           = "Alerts Notification Channel for Support Team"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.c1_notification_destination.id
  product        = "IINT"

  property {
    key   = "Alerts for Support"
    value = "Alerts raised from New Relic on Infrastructure. Please investigate."
  }
}

resource "newrelic_workflow" "c1_workflow" {
  name                  = "Challenge 1 - Examples for Alert Storm"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Issue Filter"
    type = "FILTER"
    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.alert_policy_name.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.c1_notification_channel.id
  }
}