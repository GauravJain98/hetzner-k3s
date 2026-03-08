output "server_ips" {
  value = {
    for server in hcloud_server.service :
    server.name => server.ipv4_address
  }
}