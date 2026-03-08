resource "hcloud_ssh_key" "default" {
  name       = "mac"
  public_key = file("~/.ssh/id_ed25519.pub")
}

locals {
  servers = {
    asuka   = "cx33"
    boruto  = "cx33"
    chopper = "cx33"
  }
}

resource "hcloud_server" "service" {
  for_each    = local.servers
  name        = each.key
  server_type = each.value
  image       = "ubuntu-24.04"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.default.id]

  labels = {
    Project = "K3S"
  }
}
