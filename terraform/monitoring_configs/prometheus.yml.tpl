global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'dev'
    project: 'devops-spring26'

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets:
%{ for idx, ip in private_ips ~}
          - '${ip}:9100'
%{ endfor ~}
        labels:
          env: 'dev'
          project: 'devops-spring26'
