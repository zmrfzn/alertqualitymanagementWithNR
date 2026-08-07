terraform {
  required_providers {
    newrelic = { source = "newrelic/newrelic", version = ">=3.60.0" }
  }
}

provider "newrelic" {
  account_id = var.account_id
  api_key    = var.api_key
  region     = var.region
}

resource "newrelic_one_dashboard" "aqm_scorecard" {
  name = "AQM Scorecard - Alert Noise"

  page {
    name = "Alert Noise"

    widget_billboard {
      title  = "Open issues (last 30 min)"
      row    = 1
      column = 1
      width  = 4
      height = 3
      nrql_query {
        account_id = var.account_id
        query      = "SELECT uniqueCount(issueId) FROM NrAiIssue where event in('activate','create')"
      }
    }

    widget_line {
      title  = "Issues opened over time, by policy (includes muted)"
      row    = 1
      column = 5
      width  = 8
      height = 3
      nrql_query {
        account_id = var.account_id
        query      = "SELECT count(*) FROM NrAiIncident WHERE event in ('activate','create','open') FACET policyName TIMESERIES"
      }
    }

    widget_bar {
      title  = "Issues opened by policy (includes muted)"
      row    = 4
      column = 1
      width  = 12
      height = 3
      nrql_query {
        account_id = var.account_id
        query      = "SELECT count(*) FROM NrAiIncident FACET policyName"
      }
    }

    # Un-muted (notifying) issues only. After muting is armed, the tuned
    # policies should read low here even while the widget above still counts
    # their muted issues.
    widget_bar {
      title  = "Notifying issues by policy (un-muted)"
      row    = 7
      column = 1
      width  = 12
      height = 3
      nrql_query {
        account_id = var.account_id
        query      = "SELECT uniqueCount(issueId) FROM NrAiIssue WHERE muted IS FALSE FACET policyName"
      }
    }
  }
}
