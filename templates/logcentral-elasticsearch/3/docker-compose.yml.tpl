version: "2"
services:
  elasticsearch-masters:
    image: rancher/elasticsearch-conf:v0.5.0
    labels:
      io.rancher.sidekicks: elasticsearch-base-master,elasticsearch-datavolume-masters
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    volumes_from:
    - elasticsearch-datavolume-masters
  elasticsearch-datavolume-masters:
    labels:
      io.rancher.container.start_once: 'true'
      io.rancher.container.hostname_override: container_name
      elasticsearch.datanode.config.version: '0'
      io.rancher.scheduler.affinity:host_label: ${host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    entrypoint:
    - /bin/true
    image: elasticsearch:2.4.4
    volumes:
    - logcentral-elasticsearch-masters-bin:/opt/rancher/bin
    - logcentral-elasticsearch-masters-config:/usr/share/elasticsearch/config
    - logcentral-elasticsearch-masters-data:/usr/share/elasticsearch/data
    - ${backup_volume}:/backup
  elasticsearch-base-master:
    labels:
      elasticsearch.master.config.version: '0'
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    entrypoint:
    - /opt/rancher/bin/run.sh
    image: elasticsearch:2.4.4
    volumes_from:
    - elasticsearch-datavolume-masters
    network_mode: "container:elasticsearch-masters"

  elasticsearch-datanodes:
    labels:
      io.rancher.sidekicks: elasticsearch-base-datanode,elasticsearch-datavolume-datanode
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      io.rancher.scheduler.affinity:host_label: ${host_labels}
    image: rancher/elasticsearch-conf:v0.5.0
    links:
    - elasticsearch-masters:es-masters
    volumes_from:
    - elasticsearch-datavolume-datanode
  elasticsearch-datavolume-datanode:
    labels:
      io.rancher.container.start_once: 'true'
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      elasticsearch.datanode.config.version: '0'
      io.rancher.scheduler.affinity:host_label: ${host_labels}
    entrypoint:
    - /bin/true
    image: elasticsearch:2.4.4
    links:
    - elasticsearch-masters:es-masters
    volumes:
    - logcentral-elasticsearch-datanodes-bin:/opt/rancher/bin
    - logcentral-elasticsearch-datanodes-config:/usr/share/elasticsearch/config
    - logcentral-elasticsearch-datanodes-data:/usr/share/elasticsearch/data
    - ${backup_volume}:/backup
  elasticsearch-base-datanode:
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      elasticsearch.datanode.config.version: '0'
      io.rancher.scheduler.affinity:host_label: ${host_labels}
    entrypoint:
    - /opt/rancher/bin/run.sh
    image: elasticsearch:2.4.4
    links:
    - elasticsearch-masters:es-masters
    volumes_from:
    - elasticsearch-datavolume-datanode
    network_mode: "container:elasticsearch-datanodes"

  elasticsearch-clients:
    labels:
      io.rancher.sidekicks: elasticsearch-base-clients,elasticsearch-datavolume-clients
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    image: rancher/elasticsearch-conf:v0.5.0
    links:
    - elasticsearch-masters:es-masters
    volumes_from:
    - elasticsearch-datavolume-clients
  elasticsearch-datavolume-clients:
    labels:
      io.rancher.container.start_once: 'true'
      io.rancher.container.hostname_override: container_name
      elasticsearch.datanode.config.version: '0'
      io.rancher.scheduler.affinity:host_label: ${host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    entrypoint:
    - /bin/true
    image: elasticsearch:2.4.4
    links:
    - elasticsearch-masters:es-masters
    volumes:
    - logcentral-elasticsearch-clients-bin:/opt/rancher/bin
    - logcentral-elasticsearch-clients-config:/usr/share/elasticsearch/config
    - logcentral-elasticsearch-clients-data:/usr/share/elasticsearch/data
    - ${backup_volume}:/backup
  elasticsearch-base-clients:
    labels:
      elasticsearch.client.config.version: '0'
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    entrypoint:
    - /opt/rancher/bin/run.sh
    image: elasticsearch:2.4.4
    links:
    - elasticsearch-masters:es-masters
    volumes_from:
    - elasticsearch-datavolume-clients
    network_mode: "container:elasticsearch-clients"

  kopf:
    ports:
    - "${kopf_port}:80"
    environment:
      KOPF_ES_SERVERS: es-clients:9200
      KOPF_SERVER_NAME: es.dev
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    image: rancher/kopf:v0.4.0
    links:
    - elasticsearch-clients:es-clients

{{- if eq .Values.volume_driver "rancher-ebs"}}

volumes:
  logcentral-elasticsearch-datanodes-data:
    driver: ${volume_driver}
    per_container: true
    driver_opts:
      {{.Values.volume_driver_opts}}

{{- end}}
