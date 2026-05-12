resource "google_kms_key_ring" "smarthome_keyring" {
  name     = "smarthome-keyring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "firestore_key" {
  name            = "firestore-encryption-key"
  key_ring        = google_kms_key_ring.smarthome_keyring.id
  rotation_period = "7776000s"
  purpose         = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "storage_key" {
  name            = "storage-encryption-key"
  key_ring        = google_kms_key_ring.smarthome_keyring.id
  rotation_period = "7776000s"
  purpose         = "ENCRYPT_DECRYPT"
}

resource "google_kms_crypto_key_iam_member" "firestore_kms_access" {
  crypto_key_id = google_kms_crypto_key.firestore_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gcp-sa-firestore.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "storage_kms_access" {
  crypto_key_id = google_kms_crypto_key.storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}