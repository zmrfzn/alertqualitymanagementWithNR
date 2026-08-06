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
  name = "AQM Scorecard — Alert Noise"

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
        query      = "SELECT uniqueCount(incidentId) FROM NrAiIncident WHERE event = 'open' SINCE 30 minutes ago"
      }
    }

    widget_line {
      title  = "Issues opened over time, by policy"
      row    = 1
      column = 5
      width  = 8
      height = 3
      nrql_query {
        account_id = var.account_id
        query      = "SELECT count(*) FROM NrAiIncident WHERE event = 'open' FACET policyName TIMESERIES SINCE 1 hour ago"
      }
    }

    widget_bar {
      title  = "Noisiest policies"
      row    = 4
      column = 1
      width  = 12
      height = 3
      nrql_query {
        account_id = var.account_id
        query      = "SELECT count(*) FROM NrAiIncident WHERE event = 'open' FACET policyName SINCE 2 hours ago"
      }
    }
  }
}
