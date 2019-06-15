{% from '_lib.hcl' import group_disk, task_logs, continuous_reschedule -%}

job "nextcloud-migrate" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 45

  group "migrate" {
    ${ group_disk() }

    ${ continuous_reschedule() }

    task "script" {
      ${ task_logs() }

      driver = "docker"
      config = {
        image = "liquidinvestigations/liquid-nextcloud"
        volumes = [
          "${liquid_volumes}/nextcloud/nextcloud:/var/www/html",
          "${liquid_collections}/uploads/data:/var/www/html/data/uploads/files",
        ]
        args = ["sudo", "-Eu", "www-data", "/setup.sh"]
        labels {
          liquid_task = "nextcloud-migrate"
        }
      }
      template {
        data = <<-EOF
        HTTP_PROTO = ${config.liquid_http_protocol}

        {{- range service "nextcloud-app" }}
          NEXTCLOUD_INTERNAL_STATUS_URL = http://{{.Address}}:{{.Port}}/status.php
        {{- end }}
        NEXTCLOUD_HOST = nextcloud.{{ key "liquid_domain" }}
        NEXTCLOUD_ADMIN_USER = admin
        NEXTCLOUD_ADMIN_PASSWORD = admin

        {{- range service "nextcloud-maria" }}
          MYSQL_HOST = {{.Address}}:{{.Port}}
        {{- end }}
        MYSQL_DB = nextcloud
        MYSQL_USER = nextcloud
        {{- with secret "liquid/nextcloud/nextcloud.maria" }}
          MYSQL_PASSWORD = {{.Data.secret_key}}
        {{- end }}

        {{- with secret "liquid/nextcloud/nextcloud.admin" }}
          OC_PASS = {{.Data.secret_key}}
        {{- end }}
        TIMESTAMP = {{ timestamp }}
        EOF
        destination = "local/nextcloud-migrate.env"
        env = true
      }
      resources {
        memory = 100
        cpu = 200
      }
    }
  }
}