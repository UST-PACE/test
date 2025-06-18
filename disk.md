# Move Kubelet Data to a New Disk on K3s Node

This guide explains how to format and mount a new disk, then move the Kubernetes kubelet directory (`/var/lib/kubelet`) to free up space on the root volume, which helps resolve disk pressure taints on the node.

---

## 1. Identify the New Disk

List block devices:

```bash
lsblk
```

Look for the new disk (e.g., `/dev/xvdh`) that is not mounted or formatted.

---

## 2. Format the Disk

Check if the disk is unformatted:

```bash
sudo file -s /dev/xvdh
```

If output is `data`, format it:

```bash
sudo mkfs.ext4 /dev/xvdh
```

---

## 3. Mount the Disk

Create a mount point and mount the disk:

```bash
sudo mkdir /mnt/data
sudo mount /dev/xvdh /mnt/data
```

Verify mount:

```bash
df -h /mnt/data
```

---

## 4. Make Mount Persistent

Get UUID of the disk:

```bash
sudo blkid /dev/xvdh
```

Edit `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Add the following line (replace `<UUID>` with your disk UUID):

```
UUID=<UUID> /mnt/data ext4 defaults 0 2
```

Save and exit.

Test mount:

```bash
sudo umount /mnt/data
sudo mount -a
df -h /mnt/data
```

---

## 5. Stop K3s Service

```bash
sudo systemctl stop k3s
```

---

## 6. Unmount Busy Mounts Under `/var/lib/kubelet`

List mounts under `/var/lib/kubelet`:

```bash
mount | grep /var/lib/kubelet
```

Unmount each listed mount (example):

```bash
sudo umount /var/lib/kubelet/pods/c7a7f75e-c2b6-4d0f-91c9-3c0451107e6a/volumes/kubernetes.io~projected/kube-api-access-jkxbm
sudo umount /var/lib/kubelet/pods/fdfba141-9578-41be-95a1-3c88bf787ef8/volumes/kubernetes.io~projected/kube-api-access-b7kdh
sudo umount /var/lib/kubelet/pods/bae693d2-3f50-4761-a9ae-c021372f7d33/volumes/kubernetes.io~projected/kube-api-access-hbdm2
```

---

## 7. Move Kubelet Data Directory

```bash
sudo mv /var/lib/kubelet /mnt/data/kubelet
```

---

## 8. Create Symlink for Kubelet Directory

```bash
sudo ln -s /mnt/data/kubelet /var/lib/kubelet
```

---

## 9. Restart K3s Service

```bash
sudo systemctl start k3s
```

---

## 10. Verify Node and Disk Status

Check disk usage:

```bash
df -h /
df -h /mnt/data
```

Check node status and taints:

```bash
kubectl get nodes
kubectl describe node <node-name>
```

The `node.kubernetes.io/disk-pressure` taint should be gone after kubelet has enough disk space.

---

## Troubleshooting

* If mounts under `/var/lib/kubelet` cannot be unmounted, try:

```bash
sudo lsof +D /var/lib/kubelet
```

to find processes holding them busy, then stop those processes.

* As a last resort, reboot the node:

```bash
sudo reboot
```

and repeat from step 5.

---

## Summary One-liner for Unmounting All Kubelet Mounts

```bash
mount | grep /var/lib/kubelet | awk '{print $3}' | xargs -r sudo umount
```

---

This completes the process to move kubelet data to a new disk and resolve disk pressure issues on your K3s node.
