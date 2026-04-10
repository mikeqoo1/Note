~~以下都是用192.168.199.133示範~~

# 查看硬體規格

### 看CPU

## lscpu or cat /proc/cpuinfo

Architecture:            x86_64
  CPU op-mode(s):        32-bit, 64-bit
  Address sizes:         48 bits physical, 48 bits virtual
  Byte Order:            Little Endian
CPU(s):                  64
  On-line CPU(s) list:   0-63
Vendor ID:               AuthenticAMD
  Model name:            AMD EPYC 7313 16-Core Processor
    CPU family:          25
    Model:               1
    Thread(s) per core:  2
    Core(s) per socket:  16
    Socket(s):           2
    Stepping:            1
    Frequency boost:     enabled
    CPU max MHz:         3729.4919
    CPU min MHz:         1500.0000
    BogoMIPS:            5989.04
    Flags:               fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc rep_go
                         od nopl nonstop_tsc cpuid extd_apicid aperfmperf rapl pni pclmulqdq monitor ssse3 fma cx16 pcid sse4_1 sse4_2 movbe popcnt aes xsave avx f16c rdrand lahf_lm cmp_lega
                         cy svm extapic cr8_legacy abm sse4a misalignsse 3dnowprefetch osvw ibs skinit wdt tce topoext perfctr_core perfctr_nb bpext perfctr_llc mwaitx cpb cat_l3 cdp_l3 invp
                         cid_single hw_pstate ssbd mba ibrs ibpb stibp vmmcall fsgsbase bmi1 avx2 smep bmi2 invpcid cqm rdt_a rdseed adx smap clflushopt clwb sha_ni xsaveopt xsavec xgetbv1 x
                         saves cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local clzero irperf xsaveerptr rdpru wbnoinvd amd_ppin arat npt lbrv svm_lock nrip_save tsc_scale vmcb_clean flushb
                         yasid decodeassists pausefilter pfthreshold v_vmsave_vmload vgif v_spec_ctrl umip pku ospke vaes vpclmulqdq rdpid overflow_recov succor smca
Virtualization features: 
  Virtualization:        AMD-V
Caches (sum of all):     
  L1d:                   1 MiB (32 instances)
  L1i:                   1 MiB (32 instances)
  L2:                    16 MiB (32 instances)
  L3:                    256 MiB (8 instances)
NUMA:                    
  NUMA node(s):          2
  NUMA node0 CPU(s):     0-15,32-47
  NUMA node1 CPU(s):     16-31,48-63
Vulnerabilities:         
  Itlb multihit:         Not affected
  L1tf:                  Not affected
  Mds:                   Not affected
  Meltdown:              Not affected
  Spec store bypass:     Mitigation; Speculative Store Bypass disabled via prctl
  Spectre v1:            Mitigation; usercopy/swapgs barriers and __user pointer sanitization
  Spectre v2:            Mitigation; Retpolines, IBPB conditional, IBRS_FW, STIBP always-on, RSB filling
  Srbds:                 Not affected
  Tsx async abort:       Not affected


### 看硬碟(不包含RAID)

## sudo smartctl --all /dev/sda

smartctl 7.2 2020-12-30 r5155 [x86_64-linux-5.14.0-70.13.1.el9_0.x86_64] (local build)
Copyright (C) 2002-20, Bruce Allen, Christian Franke, www.smartmontools.org

=== START OF INFORMATION SECTION ===
Vendor:               BROADCOM
Product:              MR9560-16i
Revision:             5.16
Compliance:           SPC-3
User Capacity:        1,919,816,826,880 bytes [1.91 TB]
Logical block size:   512 bytes
Rotation Rate:        Solid State Device
Logical Unit id:      0x600062b2085bcb002abdb3f2a4860a6a
Serial number:        006a0a86a4f2b3bd2a00cb5b08b26200
Device type:          disk
Local Time is:        Wed Oct  5 09:20:17 2022 CST
SMART support is:     Unavailable - device lacks SMART capability.

=== START OF READ SMART DATA SECTION ===
Current Drive Temperature:     0 C
Drive Trip Temperature:        0 C

Error Counter logging not supported

Device does not support Self Test logging

# 看硬碟空間是不是符合須求

## sudo df -h

Filesystem           Size  Used Avail Use% Mounted on
devtmpfs             126G     0  126G   0% /dev
tmpfs                126G   88K  126G   1% /dev/shm
tmpfs                 51G  283M   50G   1% /run
/dev/mapper/rl-root  1.2T   13G  1.2T   2% /
/dev/sda2           1006M  258M  749M  26% /boot
/dev/sda1            599M  6.9M  592M   2% /boot/efi
/dev/mapper/rl-home  542G  3.9G  538G   1% /home
tmpfs                 26G   56K   26G   1% /run/user/42
tmpfs                 26G   36K   26G   1% /run/user/1000

# 看有沒有做RAID

### 硬體RAID

## lspci -Dm | grep -i raid

0000:c1:00.0 "RAID bus controller" "Broadcom / LSI" "MegaRAID 12GSAS/PCIe Secure SAS39xx" "Broadcom / LSI" "MegaRAID 9560-16i"

### 軟體RAID

## cat /proc/mdstat (192.168.199.133)

Personalities : 
unused devices: <none>

# 壓力測試-放另一篇

