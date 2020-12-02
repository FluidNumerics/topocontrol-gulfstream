
resource "google_bigquery_dataset" "mitgcm_data" {
  dataset_id                  = "model_data"
  friendly_name               = "MITgcm Model Simulation Data"
  description                 = "MITgcm Post-Process Data for NSF Award #1829856"
  location                    = "US"
  project = "fsu-gulfstream"

}

resource "google_bigquery_table" "model_timeseries" {
  dataset_id = google_bigquery_dataset.mitgcm_post.dataset_id
  table_id   = "model_timeseries"
  schema = <<EOF
[
  {
    "name": "simulation_id",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "An identifier for the model simulation output"
  },
  {
    "name": "simulation_phase",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "An identifier for indicating the phase of the model run"
  },
  {
    "name": "metric_value",
    "type": "FLOAT",
    "mode": "NULLABLE",
    "description": "Time series data value"
  },
  {
    "name": "metric_name",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Time series data name"
  },
  {
    "name": "simulation_datetime",
    "type": "TIMESTAMP",
    "mode": "NULLABLE",
    "description": "%/m/%d/%Y %H:%M:%E*S"
  }
]
EOF
}

