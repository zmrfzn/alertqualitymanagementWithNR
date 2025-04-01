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

# Data source
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
  name = "Challenge 3 - Improvements to Alert Quality Management"
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

# NRQL alert condition - High Process Usage
resource "newrelic_nrql_alert_condition" "highprocess" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S3 - Host Process Usage ABOVE Acceptable Threshold"
  description                    = "Alert when process usage is high"
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
  enabled                        = true
  violation_time_limit_seconds   = 10800
  
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 60

  nrql {
    query             = "SELECT average(host.process.cpuPercent) FROM Metric FACET processId, processDisplayName WHERE entity.name = '${data.newrelic_entity.hostname.name}'"
  }

  critical {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 60
    threshold_occurrences = "all"
  }
  warning {
    operator              = "above"
    threshold             = 1.5
    threshold_duration    = 60
    threshold_occurrences = "all"
  }
}

# NRQL alert condition - High CPU
resource "newrelic_nrql_alert_condition" "highcpu" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S4 - Host CPU ABOVE Acceptable Threshold"
  description                    = "Alert when CPU usage is high"
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
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
    threshold             = 90
    threshold_duration    = 360
    threshold_occurrences = "all"
  }
  warning {
    operator              = "above"
    threshold             = 70
    threshold_duration    = 360
    threshold_occurrences = "all"
  }
}

# NRQL alert condition - High Mem
resource "newrelic_nrql_alert_condition" "highmem" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S4 - Host Memory ABOVE Acceptable Threshold"
  description                    = "Alert when Mem usage is high"
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
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
    threshold             = 90
    threshold_duration    = 120
    threshold_occurrences = "all"
  }
  warning {
    operator              = "above"
    threshold             = 70
    threshold_duration    = 120
    threshold_occurrences = "all"
  }
}

# NRQL alert condition - High Storage
resource "newrelic_nrql_alert_condition" "highstorage" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S4 - Host Storage ABOVE Acceptable Threshold"
  description                    = "Alert when Storage usage is high"
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
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
    threshold             = 80
    threshold_duration    = 120
    threshold_occurrences = "all"
  }
  warning {
    operator              = "above"
    threshold             = 60
    threshold_duration    = 120
    threshold_occurrences = "all"
  }
}

# NRQL alert condition - High Network Tx
resource "newrelic_nrql_alert_condition" "highnettx" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S5 - Host Network Tx ABOVE Acceptable Threshold"
  description                    = "Alert when network transfer usage is high"
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
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
    threshold             = 1000
    threshold_duration    = 360
    threshold_occurrences = "all"
  }
  warning {
    operator              = "above"
    threshold             = 800
    threshold_duration    = 360
    threshold_occurrences = "all"
  }
}

# NRQL alert condition - High Network Rx
resource "newrelic_nrql_alert_condition" "highnetrx" {
  policy_id                      = newrelic_alert_policy.alert_policy_name.id
  type                           = "static"
  name                           = "S5 - Host Network Rx ABOVE Acceptable Threshold"
  description                    = "Alert when network receive usage is high"
  runbook_url                    = "https://www.atlassian.com/software/confluence/templates/devops-runbook"
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
    threshold             = 1000
    threshold_duration    = 360
    threshold_occurrences = "all"
  }
  warning {
    operator              = "above"
    threshold             = 800
    threshold_duration    = 360
    threshold_occurrences = "all"
  }
}

### Alert workflows & notification ###

# Notification channel
resource "newrelic_notification_destination" "c3_notification_destination" {
  name = "Alerts to Priority Team"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.email
  }
}

resource "newrelic_notification_channel" "c3_notification_channel" {
  name           = "Alerts Notification Channel for Priority Team"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.c3_notification_destination.id
  product        = "IINT"

  property {
    key   = "Alerts for Priority Team"
    value = "Alerts have been raised from New Relic. Please take action, as our users are unable to play the game optimally."
  }
}

resource "newrelic_workflow" "c3_workflow" {
  name                  = "Challenge 3 - Improvements to Alert Quality Management"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Issue Filter"
    type = "FILTER"
    predicate {
      attribute = "accumulations.policyName"
      operator  = "EXACTLY_MATCHES"
      values    = ["Challenge 3 - Improvements to Alert Quality Management"]
    }
    # predicate {
    #   attribute = "accumulations.tags.team"
    #   operator  = "EXACTLY_MATCHES"
    #   values    = ["Application"]
    # }
    # predicate {
    #   attribute = "accumulations.tags.version"
    #   operator  = "EXACTLY_MATCHES"
    #   values    = ["v2.1"]
    # }
  }

  dynamic "enrichments" {
      for_each = var.account_type == "paid" ? [1]: []
      
      content {
          nrql {
            name = "Linux Process Enrichment - Infrastructure"
            configuration {
                query = "SELECT average(host.process.cpuPercent) as 'Processes' FROM Metric FACET processId, processDisplayName WHERE entity.name ='workshopaqm-infra' SINCE 1 hour ago"
            }
          }

          nrql {
            name = "Stress-ng Logs Enrichment - Logs"
            configuration {
                query = "SELECT count(*) FROM Log WHERE allColumnSearch('CRON', insensitive: true) AND allColumnSearch('CMD', insensitive: true) since 1 hour ago FACET message"
            }
          }
      }
    }

  destination {
    channel_id = newrelic_notification_channel.c3_notification_channel.id
  }
}

### Alert muting ###
resource "newrelic_alert_muting_rule" "silent_noise" {
    name = "Muting All Alert Storm"
    enabled = true
    description = "Stop all noisy alert storm from the Infrastructure layer."
    condition {
        conditions {
            attribute   = "policyName"
            operator    = "CONTAINS"
            values      = ["Challenge 1"]
        }
        conditions {
            attribute   = "policyName"
            operator    = "CONTAINS"
            values      = ["Challenge 2"]
        }
    operator = "AND"
    }
}