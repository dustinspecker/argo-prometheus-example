# argo-prometheus-example

Run `./deploy-argo-prometheus.sh` to create a Kubernetes cluster with kind that has
Argo and Prometheus configured.

For more information read this [post](https://dustinspecker.com/posts/viewing-argo-prometheus-metrics-using-kind/).


Run `./add-argo-prometheus-rule.sh` to create a PrometheusRule for Argo.

For more information read this [post](https://dustinspecker.com/posts/adding-a-prometheus-rule-for-argo/).


Run `GMAIL_USERNAME=username GMAIL_PASSWORD=password ./add-gmail-receiver.sh` to create an email receiver for AlertManager to send emails to a gmail account.

For more information read this [post](https://dustinspecker.com/posts/adding-alertmanager-gmail-receiver/).
