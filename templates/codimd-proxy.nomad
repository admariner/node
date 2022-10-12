{% from '_lib.hcl' import shutdown_delay, authproxy_group, task_logs, group_disk with context -%}

job "codimd-proxy" {
  datacenters = ["dc1"]
  type = "service"
  priority = 98


  ${- authproxy_group(
      'codimd',
      host='codimd.' + liquid_domain,
      upstream_port=config.port_codimd,
      group='codimd',
      redis_id=3
    ) }
}
