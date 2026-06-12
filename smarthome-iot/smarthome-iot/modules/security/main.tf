##############################################################################
# modules/security/main.tf
# Security Hardening & Audit — Minggu 4
#
# Komponen:
#   1. Security Command Center (SCC) notification
#   2. Organization Policies (constraints)
#   3. Binary Authorization untuk Cloud Run
#   4. Additional IAM hardening
#   5. VPC Service Controls (project-level)
#   6. Custom security metrics & alerts
##############################################################################

# ─── 1. Security Command Center Notification ─────────────────────────────────
# SCC membutuhkan organisasi — di project level gunakan Security Health Analytics

resource "google_scc_notification_config" "scc_alerts" {
  # SCC Notification membutuhkan Organization ID.
  # Project cloud-computing-495107 adalah personal project tanpa org → resource ini di-skip.
  # Untuk mengaktifkan: isi var.org_id di terraform.tfvars dengan Organization ID GCP.
  count = var.org_id != "" ? 1 : 0

  config_id    = "smarthome-scc-notifications"
  organization = var.org_id
  description  = "Notifikasi Security Command Center untuk Smart Home IoT project"
  pubsub_topic = google_pubsub_topic.scc_findings_topic.id

  streaming_config {
    filter = <<-EOT
      state="ACTIVE"
      AND (severity="CRITICAL" OR severity="HIGH")
      AND resource.project_display_name="${var.project_id}"
    EOT
  }
}

# ─── Pub/Sub Topic untuk SCC Findings ────────────────────────────────────────

resource "google_pubsub_topic" "scc_findings_topic" {
  project = var.project_id
  name    = "scc-security-findings"
  labels  = var.labels

  message_retention_duration = "86400s"   # 24 jam
}

resource "google_pubsub_subscription" "scc_findings_email" {
  project = var.project_id
  name    = "scc-findings-email-subscription"
  topic   = google_pubsub_topic.scc_findings_topic.name

  message_retention_duration = "86400s"
  ack_deadline_seconds       = 60

  expiration_policy {
    ttl = ""   # Tidak expire
  }
}

# ─── 2. Organization Policies ────────────────────────────────────────────────
# CATATAN: google_project_organization_policy membutuhkan roles/orgpolicy.policyAdmin
# di level Organization. Project cloud-computing-495107 adalah personal project
# tanpa Organization → semua resource ini di-skip (count = 0).
#
# Dokumentasi constraint yang seharusnya diterapkan di production:
#   - sql.restrictPublicIp         : larang Cloud SQL public IP
#   - compute.requireOsLogin       : wajibkan OS Login di VM
#   - iam.disableServiceAccountKeyCreation : larang SA key file
#   - gcp.resourceLocations        : batasi ke asia-southeast2
#   - storage.publicAccessPrevention: larang bucket public
#
# Untuk mengaktifkan: pindahkan project ke Organization dan
# ubah count = 0 menjadi count = 1 di bawah.

resource "google_project_organization_policy" "disable_cloudsql_public_ip" {
  count      = 0   # Dinonaktifkan — tidak ada akses Organization
  project    = var.project_id
  constraint = "sql.restrictPublicIp"
  boolean_policy { enforced = true }
}

resource "google_project_organization_policy" "require_os_login" {
  count      = 0
  project    = var.project_id
  constraint = "compute.requireOsLogin"
  boolean_policy { enforced = true }
}

resource "google_project_organization_policy" "disable_sa_key_creation" {
  count      = 0
  project    = var.project_id
  constraint = "iam.disableServiceAccountKeyCreation"
  boolean_policy { enforced = true }
}

resource "google_project_organization_policy" "restrict_resource_location" {
  count      = 0
  project    = var.project_id
  constraint = "gcp.resourceLocations"
  list_policy {
    allow {
      values = [
        "in:asia-southeast2-locations",
        "in:asia-locations",
      ]
    }
  }
}

resource "google_project_organization_policy" "enforce_public_access_prevention" {
  count      = 0
  project    = var.project_id
  constraint = "storage.publicAccessPrevention"
  boolean_policy { enforced = true }
}

# ─── 3. Binary Authorization ─────────────────────────────────────────────────
# Pastikan hanya container image yang sudah di-verify yang bisa di-deploy ke Cloud Run

resource "google_binary_authorization_policy" "smarthome_policy" {
  project = var.project_id

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "DRYRUN_AUDIT_LOG_ONLY"   # Audit dulu, jangan block langsung
    require_attestations_by = [
      google_binary_authorization_attestor.build_attestor.name
    ]
  }

  # cluster_admission_rules DIHAPUS:
  # Tidak ada GKE cluster di project ini. Binary Auth untuk Cloud Run
  # menggunakan default_admission_rule di atas dengan mode DRYRUN.
}

resource "google_binary_authorization_attestor" "build_attestor" {
  project = var.project_id
  name    = "smarthome-build-attestor"
  description = "Attestor untuk memvalidasi image yang di-build dari pipeline CI/CD resmi"

  attestation_authority_note {
    note_reference = google_container_analysis_note.build_note.name
  }
}

resource "google_container_analysis_note" "build_note" {
  project = var.project_id
  name    = "smarthome-build-note"

  attestation_authority {
    hint {
      human_readable_name = "SmartHome IoT CI/CD Build Attestor"
    }
  }
}

# ─── 4. IAM Security Hardening — Tambahan Minggu 4 ───────────────────────────

# Cegah semua member dari public allUsers dan allAuthenticatedUsers
# (Audit — pastikan tidak ada resource yang terbuka ke publik)
resource "google_project_iam_audit_config" "enhanced_audit" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type         = "ADMIN_READ"
    exempted_members = []   # Tidak ada yang dikecualikan dari audit
  }

  audit_log_config {
    log_type         = "DATA_READ"
    exempted_members = []
  }

  audit_log_config {
    log_type         = "DATA_WRITE"
    exempted_members = []
  }
}

# ─── 5. Custom Security Metrics & Alerts ─────────────────────────────────────

# Metrik: Deteksi akses Secret Manager yang tidak biasa
resource "google_logging_metric" "secret_access_spike" {
  project     = var.project_id
  name        = "security/secret_manager_access_count"
  description = "Monitor frekuensi akses ke Secret Manager — spike bisa indikasi compromise"
  filter      = <<-EOT
    protoPayload.serviceName="secretmanager.googleapis.com"
    AND protoPayload.methodName="AccessSecretVersion"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key        = "secret_id"
      value_type = "STRING"
    }
  }

  label_extractors = {
    "secret_id" = "EXTRACT(protoPayload.resourceName)"
  }
}

# Alert: IAM policy berubah (potensi privilege escalation)
resource "google_logging_metric" "iam_policy_change" {
  project     = var.project_id
  name        = "security/iam_policy_change_count"
  description = "Deteksi perubahan IAM policy — harus selalu melalui Terraform"
  filter      = <<-EOT
    protoPayload.serviceName="cloudresourcemanager.googleapis.com"
    AND (protoPayload.methodName="SetIamPolicy"
         OR protoPayload.methodName="UpdateProjectIamPolicy")
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "iam_change_alert" {
  project      = var.project_id
  display_name = "[SmartHome SECURITY] IAM Policy Berubah di Luar Terraform"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "IAM policy diubah"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/security/iam_policy_change_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"   # Alert segera
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [var.notification_channel_name]

  documentation {
    content   = <<-EOT
      **SECURITY ALERT: IAM Policy Berubah**

      Terdapat perubahan IAM di project `${var.project_id}`.

      Jika perubahan ini TIDAK dilakukan melalui `terraform apply`, segera investigasi kemungkinan:
      - Unauthorized access ke GCP Console
      - Compromised service account
      - Privilege escalation attempt

      **Cek log:** `gcloud logging read "protoPayload.methodName=SetIamPolicy"`
    EOT
    mime_type = "text/markdown"
  }
}

# Alert: Secret Manager diakses dari IP tidak dikenal
resource "google_monitoring_alert_policy" "secret_access_alert" {
  project      = var.project_id
  display_name = "[SmartHome SECURITY] Secret Manager Access Spike"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Akses Secret Manager meningkat drastis"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/security/secret_manager_access_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 100   # > 100 akses per 5 menit (normal seharusnya < 10)
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [var.notification_channel_name]

  documentation {
    content   = "**Secret Manager diakses lebih dari 100x dalam 5 menit.** Kemungkinan brute force atau aplikasi misbehaving."
    mime_type = "text/markdown"
  }
}
