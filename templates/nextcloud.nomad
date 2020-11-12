{% from '_lib.hcl' import shutdown_delay, authproxy_group, group_disk, task_logs with context -%}

job "nextcloud" {
  datacenters = ["dc1"]
  type = "service"
  priority = 65

  group "nextcloud" {
    ${ group_disk() }
    task "nextcloud" {
      ${ task_logs() }

      constraint {
        attribute = "{% raw %}${meta.liquid_volumes}{% endraw %}"
        operator = "is_set"
      }
      constraint {
        attribute = "{% raw %}${meta.liquid_collections}{% endraw %}"
        operator = "is_set"
      }

      driver = "docker"
      config {
        privileged = true  # for internal bind mount
        force_pull = true
        image = "${config.image('liquid-nextcloud')}"
        volumes = [
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/nextcloud19:/var/www/html",
          "{% raw %}${meta.liquid_volumes}{% endraw %}/nextcloud/data:/data",
        ]
        args = ["/bin/bash", "-c", "set -ex; chown www-data: /var/www/html /data && ( /entrypoint.sh apache2-foreground & sudo -Eu www-data /local/setup.sh )"]
        port_map {
          http = 80
        }
        labels {
          liquid_task = "nextcloud"
        }
        memory_hard_limit = ${3 * config.nextcloud_memory_limit}
      }
      resources {
        cpu = 100
        memory = ${config.nextcloud_memory_limit}
        network {
          mbits = 1
          port "http" {}
        }
      }
      env {
        NEXTCLOUD_URL = "${config.liquid_http_protocol}://nextcloud.${config.liquid_domain}"
        LIQUID_TITLE = "${config.liquid_title}"
        LIQUID_CORE_URL = "${config.liquid_core_url}"
        NEXTCLOUD_UPDATE = "1"
        NEXTCLOUD_DATA_DIR = "/data"
      }
      template {
        data = <<-EOF
        HTTP_PROTO = "${config.liquid_http_protocol}"
        NEXTCLOUD_HOST = "nextcloud.{{ key "liquid_domain" }}"
        NEXTCLOUD_ADMIN_USER = "admin"
        NEXTCLOUD_ADMIN = "admin"
        {{- with secret "liquid/nextcloud/nextcloud.admin" }}
          NEXTCLOUD_ADMIN_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}

        POSTGRES_DB = "nextcloud"
        POSTGRES_USER = "nextcloudAdmin"

        {{- with secret "liquid/nextcloud/nextcloud.postgres" }}
          POSTGRES_PASSWORD = {{.Data.secret_key | toJSON }}
        {{- end }}

        {{- range service "nextcloud-pg" }}
          POSTGRES_HOST = "{{.Address}}:{{.Port}}"
        {{- end }}

        TIMESTAMP = "${config.timestamp}"
        EOF
        destination = "local/nextcloud-pg.env"
        env = true
      }
      template {
        data = <<EOF
{% include 'nextcloud-setup.sh' %}
        EOF
        destination = "local/setup.sh"
        perms = "755"
      }
      service {
        name = "nextcloud-app"
        port = "http"
        check {
          name = "http"
          initial_status = "critical"
          type = "http"
          path = "/status.php"
          interval = "${check_interval}"
          timeout = "${check_timeout}"
          header {
            Host = ["nextcloud.${liquid_domain}"]
          }
        }
      }
    }
  }

  ${- authproxy_group(
      'nextcloud',
      host='nextcloud.' + liquid_domain,
      upstream='nextcloud-app',
    ) }

}
