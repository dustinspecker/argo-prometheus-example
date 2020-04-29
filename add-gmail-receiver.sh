#!/bin/bash

if [ -z "$GMAIL_USERNAME" ]; then
  echo "ERROR: GMAIL_USERNAME must be set" >&2
  exit 1
fi

if [ -z "$GMAIL_PASSWORD" ]; then
  echo "ERROR: GMAIL_PASSWORD must be set" >&2
  exit 1
fi


# create ~/alertmanager-main-secret.yaml
cat <<EOF > ~/alertmanager-main-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-main
  namespace: monitoring
type: Opaque
stringData:
  alertmanager.yaml: |
    receivers:
      - name: none
      - name: gmail
        email_configs:
          - send_resolved: true
            to: $GMAIL_USERNAME@gmail.com
            from: $GMAIL_USERNAME@gmail.com
            smarthost: smtp.gmail.com:587
            auth_username: $GMAIL_USERNAME@gmail.com
            auth_identity: $GMAIL_USERNAME@gmail.com
            auth_password: $GMAIL_PASSWORD
      route:
        group_by:
          - job
        receiver: none
        routes:
          - match:
              namespace: argo
            receiver: gmail
EOF

~/kubectl apply \
  --filename ~/alertmanager-main-secret.yaml
