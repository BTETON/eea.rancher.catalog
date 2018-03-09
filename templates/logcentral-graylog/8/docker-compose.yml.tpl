version: "2"
services:
  apache:
    image: eeacms/apache:2.4-2.2
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${graylog_frontend_host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      APACHE_MODULES: "http2_module"
      APACHE_CONFIG: |-
        Listen 8443
        <VirtualHost *:80>
            ServerName logs.apps.eea.europa.eu
            RewriteEngine On
            RewriteRule ^(.*)$$ https://${graylog_master_url} [R=permanent,L]
        </VirtualHost>

        <VirtualHost *:80>
            ServerName ${graylog_master_url}
            RewriteEngine On
            RewriteRule ^(.*)$$ https://%{HTTP_HOST}$$1 [R=permanent,L]
        </VirtualHost>

        <VirtualHost *:8443>
            ServerName ${graylog_master_url}

            <Proxy *>
                Order deny,allow
                Allow from all
            </Proxy>

            <Location />
                RequestHeader set X-Graylog-Server-URL "https://${graylog_master_url}/api/"
                ProxyPass http://graylog-master:9000/
                ProxyPassReverse http://graylog-master:9000/
            </Location>
        </VirtualHost>
      TZ: "${TZ}"
      LOGSPOUT: "ignore"
    depends_on:
    - graylog-master

  postfix:
    image: eeacms/postfix:2.10-3.1
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${graylog_frontend_host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      MTP_USER: "${postfix_mtp_user}"
      MTP_PASS: "${postfix_mtp_password}"
      MTP_HOST: "${graylog_master_url}"
      MTP_RELAY: "ironports.eea.europa.eu"
      MTP_PORT: "8587"
      TZ: "${TZ}"

  mongo:
    image: mongo:3.6.2
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${graylog_db_host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    volumes:
    - logcentral-db:/data/db
    - logcentral-configdb:/data/configdb
    environment:
      TZ: "${TZ}"

  graylog-master:
    image: graylog2/server:2.4.3-1
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${graylog_master_host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      GRAYLOG_IS_MASTER: "true"
      GRAYLOG_REST_LISTEN_URI: "http://0.0.0.0:9000/api/"
      GRAYLOG_WEB_LISTEN_URI: "http://0.0.0.0:9000/"
      GRAYLOG_REST_TRANSPORT_URI: "https://${graylog_master_url}/api/"
      GRAYLOG_WEB_ENDPOINT_URI: "https://${graylog_master_url}/api/"
      GRAYLOG_TRANSPORT_EMAIL_ENABLED: "true"
      GRAYLOG_TRANSPORT_EMAIL_HOSTNAME: "postfix"
      GRAYLOG_TRANSPORT_EMAIL_PORT: "25"
      GRAYLOG_TRANSPORT_EMAIL_SUBJECT_PREFIX: "[graylog2]"
      GRAYLOG_TRANSPORT_EMAIL_FROM_EMAIL: "noreply@eea.europa.eu"
      GRAYLOG_TRANSPORT_EMAIL_WEB_INTERFACE_URL: "https://${graylog_master_url}"
      GRAYLOG_TRANSPORT_EMAIL_USE_AUTH: "false"
      GRAYLOG_TRANSPORT_EMAIL_USE_TLS: "false"
      GRAYLOG_TRANSPORT_EMAIL_USE_SSL: "false"
      GRAYLOG_HEAP_SIZE: "${graylog_heap_size}"
      GRAYLOG_PASSWORD_SECRET: "${graylog_secret}"
      GRAYLOG_ROOT_PASSWORD_SHA2: "${graylog_root_password}"
      GRAYLOG_ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
      TZ: "${TZ}"
    depends_on:
    - mongo
    - postfix
    external_links:
    - ${elasticsearch_link}:elasticsearch

  graylog-client:
    image: graylog2/server:2.4.3-1
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${graylog_client_host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      GRAYLOG_IS_MASTER: "false"
      GRAYLOG_REST_LISTEN_URI: "http://0.0.0.0:9000/api/"
      GRAYLOG_WEB_LISTEN_URI: "http://0.0.0.0:9000/"
      GRAYLOG_REST_TRANSPORT_URI: "https://${graylog_master_url}/api/"
      GRAYLOG_WEB_ENDPOINT_URI: "https://${graylog_master_url}/api/"
      GRAYLOG_TRANSPORT_EMAIL_ENABLED: "true"
      GRAYLOG_TRANSPORT_EMAIL_HOSTNAME: "postfix"
      GRAYLOG_TRANSPORT_EMAIL_PORT: "25"
      GRAYLOG_TRANSPORT_EMAIL_SUBJECT_PREFIX: "[graylog2]"
      GRAYLOG_TRANSPORT_EMAIL_FROM_EMAIL: "noreply@eea.europa.eu"
      GRAYLOG_TRANSPORT_EMAIL_WEB_INTERFACE_URL: "https://${graylog_master_url}"
      GRAYLOG_TRANSPORT_EMAIL_USE_AUTH: "false"
      GRAYLOG_TRANSPORT_EMAIL_USE_TLS: "false"
      GRAYLOG_TRANSPORT_EMAIL_USE_SSL: "false"
      GRAYLOG_HEAP_SIZE: "-Xms2g -Xmx4g"
      GRAYLOG_PASSWORD_SECRET: "${graylog_secret}"
      GRAYLOG_ROOT_PASSWORD_SHA2: "${graylog_root_password}"
      GRAYLOG_ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
      TZ: "${TZ}"
    depends_on:
    - mongo
    - postfix
    - graylog-master
    external_links:
    - ${elasticsearch_link}:elasticsearch

  loadbalancer:
    image: eeacms/logcentralbalancer:2.3
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label: ${graylog_frontend_host_labels}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    ports:
    - "1514:1514/tcp"
    - "1514:1514/udp"
    - "12201:12201/udp"
    - "12201:12201/tcp"
    environment:
      GRAYLOG_HOSTS: "graylog-master,graylog-client"
      LOGSPOUT: "ignore"
      TZ: "${TZ}"
    depends_on:
    - graylog-master
    - graylog-client

{{- if eq .Values.volume_driver "rancher-ebs"}}

volumes:
  logcentral-db:
    driver: ${volume_driver}
    driver_opts:
      {{.Values.volume_driver_opts}}

{{- end}}
