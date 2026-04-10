# Rocky Linux 9.6 / RHEL 9.6 的 dracut bug

這是 Rocky Linux 9.6 / RHEL 9.6 的 dracut bug 導致 LVM root 掛載失敗。

在該版本中，dracut 某些情況下沒有自動包含 lvm 或 mdraid module，尤其是使用 md RAID + LVM 的系統。

所以 initramfs 裡沒有對應的模組，導致一開機就找不到 root LV。

永久修正（避免下次更新再炸）

建立 /etc/dracut.conf.d/enable-lvm.conf：

```bash
add_dracutmodules+=" lvm mdraid "
```

然後：

```bash
dracut --regenerate-all -f
```

重新更新到最新的9.6 (5.14.0-578.21.1.el9_6) 移除舊的9.6(5.14.0-570.21.el9_6)

```bash
sudo dnf remove kernel-core-5.14.0-570.21.el9_6.x86_64 kernel-modules-5.14.0-570.21.el9_6.x86_64 kernel-5.14.0-570.21.el9_6.x86_64
```
