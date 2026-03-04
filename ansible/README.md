# Ansible Infrastructure Documentation

## Overview

Two-stage deployment for a 3-node K3S Kubernetes cluster on Hetzner servers.

**Nodes:**
| Hostname | IP              | Role            |
|----------|-----------------|-----------------|
| asuka    | 195.201.99.103  | K3S Server (control plane) |
| boruto   | 195.201.99.218  | K3S Agent (worker) |
| chopper  | 195.201.99.207  | K3S Agent (worker) |

**Run order:**
1. `initial-setup/` — must run first as root
2. `cluster/` — runs after initial setup as sysadmin

---

## Stage 1: Initial Setup

**Directory:** `initial-setup/`
**Run as:** root
**Command:** `ansible-playbook -i ../inventory/hosts.ini site.yml`

### Play 1 — Create Admin User (`admin-user` role)

Creates a non-root user `sysadmin` with passwordless sudo and SSH key access.

| Step | Action |
|------|--------|
| 1 | Create `sysadmin` user with `/bin/bash` shell and home directory |
| 2 | Add `sysadmin` to the `sudo` group |
| 3 | Create `/etc/sudoers.d/sysadmin` with `NOPASSWD:ALL` |
| 4 | Create `~/.ssh` directory (mode 700) |
| 5 | Copy local `~/.ssh/id_ed25519.pub` to `authorized_keys` |
| 6 | Verify SSH access to `sysadmin` account |

### Play 2 — Security Hardening (`security-hardening` role)

#### SSH Hardening

Deploys hardened `sshd_config` from template, validates syntax, then restarts sshd.

Key settings applied:
- `PermitRootLogin no`
- `PubkeyAuthentication yes`
- `PasswordAuthentication no`
- `X11Forwarding no`
- `MaxAuthTries 3`
- `MaxSessions 5`
- `AllowUsers sysadmin`
- Client keep-alive: 5 min / 2 missed packets

#### Firewall (UFW)

| Step | Action |
|------|--------|
| 1 | Install UFW |
| 2 | Set default policy: deny incoming, allow outgoing |
| 3 | Allow 22/TCP (SSH) |
| 4 | Allow 80/TCP (HTTP) |
| 5 | Allow 443/TCP (HTTPS) |
| 6 | Allow 6443/TCP (K3S API server) |
| 7 | Allow 10250/TCP (Kubelet metrics) |
| 8 | Allow 2379-2380/TCP (etcd) |
| 9 | Allow 8472/UDP (Flannel VXLAN) |
| 10 | Allow 51820/UDP (WireGuard IPv4) |
| 11 | Allow 51821/UDP (WireGuard IPv6) |
| 12 | Enable UFW |

#### Automatic Security Updates

| Step | Action |
|------|--------|
| 1 | Install `unattended-upgrades` |
| 2 | Enable automatic security patches |

---

## Stage 2: K3S Cluster

**Directory:** `cluster/`
**Run as:** sysadmin (sudo enabled)
**Command:** `ansible-playbook -i ../inventory/hosts.ini site.yml`
**K3S version:** v1.31.4+k3s1

### Play 1 — Common Prerequisites (all nodes)

Prepares every node for K3S installation.

| Step | Action |
|------|--------|
| 1 | Install `curl` and `apt-transport-https` |
| 2 | Load kernel modules: `br_netfilter`, `overlay` |
| 3 | Persist modules in `/etc/modules-load.d/k3s.conf` |
| 4 | Set sysctl: `net.bridge.bridge-nf-call-iptables = 1` |
| 5 | Set sysctl: `net.bridge.bridge-nf-call-ip6tables = 1` |
| 6 | Set sysctl: `net.ipv4.ip_forward = 1` |

### Play 2 — K3S Server (asuka only)

Installs K3S control plane.

| Step | Action |
|------|--------|
| 1 | Check if K3S is already installed at `/usr/local/bin/k3s` |
| 2 | Download and run K3S install script (skipped if already installed) |
| 3 | Enable and start `k3s` systemd service |
| 4 | Wait up to 150s for node to become Ready (polls `k3s kubectl get nodes`) |
| 5 | Read node join token from `/var/lib/rancher/k3s/server/node-token` |
| 6 | Store token as fact `k3s_token` for agent nodes to use |

Extra args: `--write-kubeconfig-mode 644`

### Play 3 — K3S Agents (boruto, chopper)

Joins worker nodes to the cluster.

| Step | Action |
|------|--------|
| 1 | Check if K3S agent is already installed |
| 2 | Download and run K3S install script in agent mode (skipped if already installed) |
| 3 | Enable and start `k3s-agent` systemd service |

Agent connects to: `https://195.201.99.103:6443` using token from `hostvars['asuka']['k3s_token']`

### Play 4 — Verify Cluster (asuka)

Validates cluster health after deployment.

| Step | Action |
|------|--------|
| 1 | Poll until 3 nodes report `Ready` (30 retries × 10s = 5 min timeout) |
| 2 | Run `k3s kubectl get nodes -o wide` |
| 3 | Print node list to console |
