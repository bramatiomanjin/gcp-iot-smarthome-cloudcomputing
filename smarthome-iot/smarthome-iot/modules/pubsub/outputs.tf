##############################################################################
# modules/pubsub/outputs.tf
##############################################################################

output "sensor_topic_id" {
  description = "ID topik data sensor"
  value       = google_pubsub_topic.sensor_data.id
}

output "sensor_topic_name" {
  description = "Nama topik data sensor"
  value       = google_pubsub_topic.sensor_data.name
}

output "alert_topic_id" {
  description = "ID topik alert"
  value       = google_pubsub_topic.alert.id
}

output "alert_topic_name" {
  description = "Nama topik alert"
  value       = google_pubsub_topic.alert.name
}

output "dead_letter_topic_id" {
  description = "ID dead-letter topic"
  value       = google_pubsub_topic.dead_letter.id
}

output "cloudrun_subscription_name" {
  description = "Nama subscription push ke Cloud Run"
  value       = google_pubsub_subscription.cloudrun_push.name
}
