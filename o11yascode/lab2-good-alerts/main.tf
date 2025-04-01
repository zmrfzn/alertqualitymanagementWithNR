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
data "newrelic_entity" "appname" {
  name = var.appname # Note: This must be an exact match of your entity in New Relic (Case sensitive)
  type = "APPLICATION"
  domain = "APM"
}

data "newrelic_entity" "hostname" {
  name = var.hostname # Note: This must be an exact match of your entity in New Relic (Case sensitive)
  type = "HOST"
  domain = "INFRA"
}

# resource to create, update, and delete tags for a New Relic entity - App
resource "newrelic_entity_tags" "appname" {
    guid = data.newrelic_entity.appname.guid

    tag {
        key = "escalation"
        values = ["High"]
    }

    tag {
        key = "stack"
        values = ["Node.js", "Express", "Public"]
    }

    tag {
        key = "version"
        values = ["v2.1"]
    }

    tag {
        key = "team"
        values = ["Application"]
    }
}

# resource to create, update, and delete tags for a New Relic entity - Host
resource "newrelic_entity_tags" "hostname" {
    guid = data.newrelic_entity.hostname.guid

    tag {
        key = "escalation"
        values = ["High"]
    }

    tag {
        key = "environment"
        values = ["Cloud", "GCP", "Production"]
    }

    tag {
        key = "revision"
        values = ["v5.2"]
    }

    tag {
        key = "team"
        values = ["Platform"]
    }
}

### Alert policy & condition ###

# Alert policy
resource "newrelic_alert_policy" "alert_policy_name" {
  name = "Challenge 2 - Introduction to Alert Quality Management"
  incident_preference = "PER_CONDITION"
}

# NRQL alert condition - S1 - Game Main API ABOVE 90% Percentile - including SIGNAL LOST
resource "newrelic_nrql_alert_condition" "GameMainAPI" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S1 - Game Main API ABOVE 90% Percentile - including SIGNAL LOST"
  description                    = "The main API route for the game is experiencing poor performance."
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 60
  expiration_duration = 600
  open_violation_on_expiration = true
  close_violations_on_expiration = true

  nrql {
    query             = "SELECT percentile(duration, 90) FROM Transaction WHERE appName = '${data.newrelic_entity.appname.name}' AND name = 'WebTransaction/Expressjs/GET//game'"
  }

  critical {
    operator              = "above"
    threshold             = 4
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - S2 - Game Serving Assets ABOVE 20% Error Threshold
resource "newrelic_nrql_alert_condition" "GameServingAssets" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S2 - Game Serving Assets ABOVE 20% Error Threshold"
  description                    = "The game assets serving is experiencing a high amount of errors affecting gameplay."
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 60

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.apm.application.errorRate) * 100 FROM Metric WHERE entity.name = '${data.newrelic_entity.appname.name}'"
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

# NRQL alert condition - S2 - Game Processes ABOVE Acceptable Threshold
resource "newrelic_nrql_alert_condition" "GameProcesses" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S2 - Game Processes ABOVE Acceptable Threshold"
  description                    = "The game processes might be affecting resource consumption for users to have an optimal gameplay."
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 60

  nrql {
    query             = "SELECT average(host.process.cpuPercent) FROM Metric FACET processId, processDisplayName WHERE entity.name ='${data.newrelic_entity.hostname.name}' AND process.name LIKE '%stress-ng%' or process.name = 'node'"
  }

  critical {
    operator              = "above"
    threshold             = 10
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 8
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - S3 - Game Throughput DEVIATED from Dynamic Threshold
resource "newrelic_nrql_alert_condition" "GameThroughput" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "baseline"
  name                           = "S3 - Game Throughput DEVIATED from Dynamic Threshold"
  description                    = "The game received a throughput that deviated from the configured threshold, as seen with previous data points."
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 60

  baseline_direction = "upper_only"

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.apm.application.throughput) FROM Metric WHERE entity.name ='${data.newrelic_entity.appname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 10
    threshold_duration    = 180
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 8
    threshold_duration    = 180
    threshold_occurrences = "at_least_once"
  }
}

# NRQL alert condition - S3 - Game Response Time DEVIATED from Dynamic Threshold
resource "newrelic_nrql_alert_condition" "GameResponseTime" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "baseline"
  name                           = "S3 - Game Response Time DEVIATED from Dynamic Threshold"
  description                    = "The game response time deviated from the configured threshold, as seen with previous data points."
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 60

  baseline_direction = "upper_only"

  nrql {
    query             = "SELECT average(newrelic.goldenmetrics.apm.application.responseTimeMs) FROM Metric WHERE entity.name = '${data.newrelic_entity.appname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  warning {
    operator              = "above"
    threshold             = 4
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
}

### Alert workflows & notification ###

# Notification channel
resource "newrelic_notification_destination" "c2_notification_destination" {
  name = "Alerts to Application Team"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.email
  }
}

resource "newrelic_notification_channel" "c2_notification_channel" {
  name           = "Alerts Notification Channel for Application Team"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.c2_notification_destination.id
  product        = "IINT"

  property {
    key   = "Alerts for Application Team"
    value = "Alerts raised from New Relic on APM. Please investigate."
  }
}

# Workflow
resource "newrelic_workflow" "c2_workflow" {
  name                  = "Challenge 2 - Introduction to Alert Quality Management"
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
    channel_id = newrelic_notification_channel.c2_notification_channel.id
  }
}