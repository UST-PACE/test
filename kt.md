# Network Architecture Documentation

## 🔹 Setup Overview
- Infrastructure deployed using **Terraform**  
  Repo: [UST-PACE/sflabs](https://github.com/UST-PACE/sflabs/tree/main/pace-multitenant/terraform)  
- Current subscription: **PAYG**, migration to **BYOL (1 year)** in progress.  
- Core components:
  - **FortiGate VM** (firewall, 3 NICs attached)  
  - **Rancher server**  
  - **OpenVPN Access Server**  

---

## 🔹 Networking Details
- **VPC CIDR:** `10.0.0.0/16`

**Subnets**  
- `10.0.99.0/24` → `fortigate-dmz-private-us-east-1a` (NAT GW)  
- `10.0.98.0/24` → `rancher-fortigate-private-us-east-1a` (NAT GW)  
- `10.0.9.0/24` → `fortigate-extranet-public-us-east-1a` (Internet GW)  

**FortiGate NICs**  
- **NIC0 (Private):** `10.0.98.115` (Rancher subnet)  
- **NIC1 (Public):** `10.0.9.160`, `10.0.9.161`  
  - Public IPs: `54.243.133.24x` (Primary), `34.194.93.22x` (Secondary)  
- **NIC2 (DMZ):** `10.0.99.147` (DMZ subnet)  

**Other Servers**  
- Rancher: `10.0.98.168`  
- OpenVPN-AS: `10.0.99.115`  

---

## 🔹 Connectivity & Data Flow
- **Customer edge system** connects to **OpenVPN-AS** via OpenVPN client  
  - Edge static IP: `10.8.0.10`  
  - Ports: `1194`, `443`  
- **Rancher access**:  
  - Connect VPN → Use Rancher IP `10.0.98.168`  
- **Routing**  
  - OpenVPN split tunnel → internet traffic stays local at edge ISP  
  - Rancher & OpenVPN servers → static routes towards **FortiGate firewall**  
  - Static routes added for **EKS cluster subnets** → Jenkins ↔ Rancher communication enabled  
  - SSH to Rancher & OpenVPN servers via peer machines due to routing  

---

## 🔹 References
- OpenVPN user creation & static IP guide:  
  [openvpn-access-server.md](https://github.com/UST-PACE/sflabs/blob/feature/SF-4882/docs/openvpn-as/openvpn-access-server.md)  
- Edge on-boarding scripts:  
  [vc_edge_prereq](https://github.com/UST-PACE/sflabs/tree/feature/SF-4882/scripts/vc_edge_prereq)  

---
