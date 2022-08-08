# Lynis Linux的資安檢測工具

## 安裝

```bash
git clone https://github.com/CISOfy/lynis

使用sudo的root權限的話, 記得先 sudo chown -R 0:0 lynis, 才不會有權限問題
```

## 說明


顯示檢查的項目

lynis show groups

```txt
accounting  跟蹤
authentication 用戶檢查
banners 
boot_services
containers 檢查Docker
crypto 檢查Certificates
databases 檢查Mysql Redis MomgoDB
dns
file_integrity
file_permissions
filesystems
firewalls
hardening
homedirs
insecure_services
kernel
kernel_hardening
ldap
logging
mac_frameworks
mail_messaging
malware
memory_processes
nameservices
networking
php
ports_packages
printers_spoolers
scheduling
shells
snmp
squid
ssh
storage
storage_nfs
system_integrity
time
tooling
usb
virtualization
webservers
```

顯示項目的明細表

lynis show tests

```txt
# Test       OS         Description
# ======================================================================================
ACCT-2754  FreeBSD    Check for available FreeBSD accounting information (security)
ACCT-2760  OpenBSD    Check for available OpenBSD accounting information (security)
ACCT-9622  Linux      Check for available Linux accounting information (security)
ACCT-9626  Linux      Check for sysstat accounting data (security)
ACCT-9628  Linux      Check for auditd (security)
ACCT-9630  Linux      Check for auditd rules (security)
ACCT-9632  Linux      Check for auditd configuration file (security)
ACCT-9634  Linux      Check for auditd log file (security)
ACCT-9636  Linux      Check for Snoopy wrapper and logger (security)
ACCT-9650  Solaris    Check Solaris audit daemon (security)
ACCT-9652  Solaris    Check auditd SMF status (security)
ACCT-9654  Solaris    Check BSM auditing in /etc/system (security)
ACCT-9656  Solaris    Check BSM auditing in module list (security)
ACCT-9660  Solaris    Check location of audit events (security)
ACCT-9662  Solaris    Check Solaris auditing stats (security)
ACCT-9670  Linux      Check for cmd tooling (security)
ACCT-9672  Linux      Check cmd configuration file (security)
AUTH-9204             Check users with an UID of zero (security)
AUTH-9208             Check non-unique accounts in passwd file (security)
AUTH-9212             Test group file (security)
AUTH-9216             Check group and shadow group files (security)
AUTH-9218  FreeBSD    Check harmful login shells (security)
AUTH-9222             Check for non unique groups (security)
AUTH-9226             Check non unique group names (security)
AUTH-9228             Check password file consistency with pwck (security)
AUTH-9229             Check password hashing methods (security)
AUTH-9230             Check group password hashing rounds (security)
AUTH-9234             Query user accounts (security)
AUTH-9240             Query NIS+ authentication support (security)
AUTH-9242             Query NIS authentication support (security)
AUTH-9250             Checking sudoers file (security)
AUTH-9252             Check sudoers file (security)
AUTH-9254  Solaris    Solaris passwordless accounts (security)
AUTH-9262             Checking presence password strength testing tools (PAM) (security)
AUTH-9264             Checking presence pam.conf (security)
AUTH-9266             Checking presence pam.d files (security)
AUTH-9268             Checking presence pam.d files (security)
AUTH-9278             Checking LDAP pam status (security)
AUTH-9282             Checking password protected account without expire date (security)
AUTH-9283             Checking accounts without password (security)
AUTH-9284             Checking locked user accounts in /etc/passwd (security)
AUTH-9286             Checking user password aging (security)
AUTH-9288             Checking for expired passwords (security)
AUTH-9304  Solaris    Check single user login configuration (security)
AUTH-9306  HP-UX      Check single boot authentication (security)
AUTH-9308  Linux      Check single user login configuration (security)
AUTH-9328             Default umask values (security)
AUTH-9340  Solaris    Solaris account locking (security)
AUTH-9402             Query LDAP authentication support (security)
AUTH-9406             Query LDAP servers in client configuration (security)
AUTH-9408             Logging of failed login attempts via /etc/login.defs (security)
AUTH-9409  OpenBSD    Check for doas file (security)
AUTH-9410  OpenBSD    Check for doas file permissions (security)
BANN-7113  FreeBSD    Check COPYRIGHT banner file (security)
BANN-7124             Check issue banner file (security)
BANN-7126             Check issue banner file contents (security)
BANN-7128             Check issue.net banner file (security)
BANN-7130             Check issue.net banner file contents (security)
BOOT-5102  AIX        Check for AIX boot device (security)
BOOT-5104             Determine service manager (security)
BOOT-5106  MacOS      Check EFI boot file on macOS (security)
BOOT-5108  Linux      Test Syslinux boot loader (security)
BOOT-5109  Linux      Test rEFInd boot loader (security)
BOOT-5116             Check if system is booted in UEFI mode (security)
BOOT-5117  Linux      Check for systemd-boot boot loader (security)
BOOT-5121             Check for GRUB boot loader presence (security)
BOOT-5122             Check for GRUB boot password (security)
BOOT-5124  FreeBSD    Check for FreeBSD boot loader presence (security)
BOOT-5126  NetBSD     Check for NetBSD boot loader presence (security)
BOOT-5139             Check for LILO boot loader presence (security)
BOOT-5140             Check for ELILO boot loader presence (security)
BOOT-5142             Check SPARC Improved boot loader (SILO) (security)
BOOT-5155             Check for YABOOT boot loader configuration file (security)
BOOT-5159  OpenBSD    Check for OpenBSD boot loader presence (security)
BOOT-5165  FreeBSD    Check for FreeBSD boot services (security)
BOOT-5170  Solaris    Check for Solaris boot daemons (security)
BOOT-5177  Linux      Check for Linux boot and running services (security)
BOOT-5180  Linux      Check for Linux boot services (Debian style) (security)
BOOT-5184             Check permissions for boot files/scripts (security)
BOOT-5202             Check uptime of system (security)
BOOT-5260             Check single user mode for systemd (security)
BOOT-5261  DragonFly  Check for DragonFly boot loader presence (security)
BOOT-5262  OpenBSD    Check for OpenBSD boot daemons (security)
BOOT-5263  OpenBSD    Check permissions for boot files/scripts (security)
BOOT-5264  Linux      Run systemd-analyze security (security)
CONT-8004  Solaris    Query running Solaris zones (security)
CONT-8102             Checking Docker status and information (security)
CONT-8104             Checking Docker info for any warnings (security)
CONT-8106             Gather basic stats from Docker (security)
CONT-8107             Check number of unused Docker containers (performance)
CONT-8108             Check file permissions for Docker files (security)
CORE-1000             Check all system binaries (performance)
CRYP-7902             Check expire date of SSL certificates (security)
CRYP-7930  Linux      Determine if system uses LUKS encryption (security)
CRYP-7931  Linux      Determine if system uses encrypted swap (security)
CRYP-8002  Linux      Gather kernel entropy (security)
CRYP-8004  Linux      Presence of hardware random number generators (security)
CRYP-8005  Linux      Presence of software pseudo random number generators (security)
CRYP-8006  Linux      Check MemoryOverwriteRequest bit to protect against cold-boot attacks (security)
DNS-1600              Validating that the DNSSEC signatures are checked (security)
DBS-1804              Checking active MySQL process (security)
DBS-1816              Checking MySQL root password (security)
DBS-1818              MongoDB status (security)
DBS-1820              Check MongoDB authentication (security)
DBS-1826              Checking active PostgreSQL processes (security)
DBS-1828              PostgreSQL configuration files (security)
DBS-1840              Checking active Oracle processes (security)
DBS-1860              Checking active DB2 instances (security)
DBS-1880              Checking active Redis processes (security)
DBS-1882              Redis configuration file (security)
DBS-1884              Redis configuration (requirepass) (security)
DBS-1886              Redis configuration (CONFIG command renamed) (security)
DBS-1888              Redis configuration (bind on localhost) (security)
FILE-6310             Checking /tmp, /home and /var directory (security)
FILE-6311             Checking LVM volume groups (security)
FILE-6312             Checking LVM volumes (security)
FILE-6323  Linux      Checking EXT file systems (security)
FILE-6329             Checking FFS/UFS file systems (security)
FILE-6330  FreeBSD    Checking ZFS file systems (security)
FILE-6332             Checking swap partitions (security)
FILE-6336             Checking swap mount options (security)
FILE-6344  Linux      Checking proc mount options (security)
FILE-6354             Searching for old files in /tmp (security)
FILE-6362             Checking /tmp sticky bit (security)
FILE-6363             Checking /var/tmp sticky bit (security)
FILE-6368  Linux      Checking ACL support on root file system (security)
FILE-6372  Linux      Checking / mount options (security)
FILE-6374  Linux      Linux mount options (security)
FILE-6376  Linux      Determine if /var/tmp is bound to /tmp (security)
FILE-6394  Linux      Test swappiness of virtual memory (performance)
FILE-6410             Checking Locate database (security)
FILE-6430             Disable mounting of some filesystems (security)
FILE-6439  DragonFly  Checking HAMMER PFS mounts (security)
FILE-7524             Perform file permissions check (security)
FINT-4310             AFICK availability (security)
FINT-4314             AIDE availability (security)
FINT-4315             Check AIDE configuration file (security)
FINT-4316             Presence of AIDE database and size check (security)
FINT-4318             Osiris availability (security)
FINT-4322             Samhain availability (security)
FINT-4326             Tripwire availability (security)
FINT-4328             OSSEC syscheck daemon running (security)
FINT-4330             mtree availability (security)
FINT-4334             Check lfd daemon status (security)
FINT-4336             Check lfd configuration status (security)
FINT-4338             osqueryd syscheck daemon running (security)
FINT-4339  Linux      Check IMA/EVM Status (security)
FINT-4340  Linux      Check dm-integrity status (security)
FINT-4341  Linux      Check dm-verity status (security)
FINT-4350             File integrity software installed (security)
FINT-4402             Checksums (SHA256 or SHA512) (security)
FIRE-4502  Linux      Check iptables kernel module (security)
FIRE-4508             Check used policies of iptables chains (security)
FIRE-4512             Check iptables for empty ruleset (security)
FIRE-4513             Check iptables for unused rules (security)
FIRE-4518             Check pf firewall components (security)
FIRE-4520             Check pf configuration consistency (security)
FIRE-4524             Check for CSF presence (security)
FIRE-4526  Solaris    Check ipf status (security)
FIRE-4530  FreeBSD    Check IPFW status (security)
FIRE-4532  MacOS      Check macOS application firewall (security)
FIRE-4534  MacOS      Check for outbound firewalls (security)
FIRE-4536  Linux      Check nftables status (security)
FIRE-4538  Linux      Check nftables basic configuration (security)
FIRE-4540  Linux      Test for empty nftables configuration (security)
FIRE-4586             Check firewall logging (security)
FIRE-4590             Check firewall status (security)
FIRE-4594             Check for APF presence (security)
HOME-9302             Create list with home directories (security)
HOME-9304             Test permissions of user home directories (security)
HOME-9306             Test ownership of user home directories (security)
HOME-9310             Checking for suspicious shell history files (security)
HOME-9350             Collecting information from home directories (security)
HRDN-7220             Check if one or more compilers are installed (security)
HRDN-7222             Check compiler permissions (security)
HRDN-7230             Check for malware scanner (security)
HRDN-7231  Linux      Check for registered non-native binary formats (security)
HTTP-6622             Checking Apache presence (security)
HTTP-6624             Testing main Apache configuration file (security)
HTTP-6626             Testing other Apache configuration file (security)
HTTP-6632             Determining all available Apache modules (security)
HTTP-6640             Determining existence of specific Apache modules (security)
HTTP-6641             Determining existence of specific Apache modules (security)
HTTP-6643             Determining existence of specific Apache modules (security)
HTTP-6702             Check nginx process (security)
HTTP-6704             Check nginx configuration file (security)
HTTP-6706             Check for additional nginx configuration files (security)
HTTP-6708             Check discovered nginx configuration settings (security)
HTTP-6710             Check nginx SSL configuration settings (security)
HTTP-6712             Check nginx access logging (security)
HTTP-6714             Check for missing error logs in nginx (security)
HTTP-6716             Check for debug mode on error log in nginx (security)
HTTP-6720             Check Nginx log files (security)
INSE-8000             Installed inetd package (security)
INSE-8002             Status of inet daemon (security)
INSE-8004             Presence of inetd configuration file (security)
INSE-8006             Check configuration of inetd when it is disabled (security)
INSE-8016             Check for telnet via inetd (security)
INSE-8050  MacOS      Check for insecure services on macOS systems (security)
INSE-8100             Installed xinetd package (security)
INSE-8116             Insecure services enabled via xinetd (security)
INSE-8200             Usage of TCP wrappers (security)
INSE-8300             Presence of rsh client (security)
INSE-8302             Presence of rsh server (security)
INSE-8310             Presence of telnet client (security)
INSE-8312             Presence of telnet server (security)
INSE-8314             Presence of NIS client (security)
INSE-8316             Presence of NIS server (security)
INSE-8318             Presence of TFTP client (security)
INSE-8320             Presence of TFTP server (security)
KRNL-5622  Linux      Determine Linux default run level (security)
KRNL-5677  Linux      Check CPU options and support (security)
KRNL-5695  Linux      Determine Linux kernel version and release number (security)
KRNL-5723  Linux      Determining if Linux kernel is monolithic (security)
KRNL-5726  Linux      Checking Linux loaded kernel modules (security)
KRNL-5728  Linux      Checking Linux kernel config (security)
KRNL-5730  Linux      Checking disk I/O kernel scheduler (security)
KRNL-5745  FreeBSD    Checking FreeBSD loaded kernel modules (security)
KRNL-5770  Solaris    Checking active kernel modules (security)
KRNL-5788  Linux      Checking availability new Linux kernel (security)
KRNL-5820  Linux      Checking core dumps configuration (security)
KRNL-5830  Linux      Checking if system is running on the latest installed kernel (security)
KRNL-5831  DragonFly  Checking DragonFly loaded kernel modules (security)
KRNL-6000             Check sysctl key pairs in scan profile (security)
LDAP-2219             Check running OpenLDAP instance (security)
LDAP-2224             Check presence slapd.conf (security)
LOGG-2130             Check for running syslog daemon (security)
LOGG-2132             Check for running syslog-ng daemon (security)
LOGG-2134             Checking Syslog-NG configuration file consistency (security)
LOGG-2136             Check for running systemd journal daemon (security)
LOGG-2138  Linux      Checking kernel logger daemon on Linux (security)
LOGG-2142  Linux      Checking minilog daemon (security)
LOGG-2146             Checking logrotate.conf and logrotate.d (security)
LOGG-2148             Checking logrotated files (security)
LOGG-2150             Checking directories in logrotate configuration (security)
LOGG-2152             Checking loghost (security)
LOGG-2153             Checking loghost is not localhost (security)
LOGG-2154             Checking syslog configuration file (security)
LOGG-2160             Checking /etc/newsyslog.conf (security)
LOGG-2162             Checking directories in /etc/newsyslog.conf (security)
LOGG-2164             Checking files specified /etc/newsyslog.conf (security)
LOGG-2170             Checking log paths (security)
LOGG-2180             Checking open log files (security)
LOGG-2190             Checking for deleted files in use (security)
LOGG-2192             Checking for opened log files that are empty (security)
LOGG-2210             Check for running metalog daemon (security)
LOGG-2230             Check for running RSyslog daemon (security)
LOGG-2240             Check for running RFC 3195 compliant daemon (security)
MACF-6204             Check AppArmor presence (security)
MACF-6208             Check if AppArmor is enabled (security)
MACF-6232             Check SELINUX presence (security)
MACF-6234             Check SELINUX status (security)
MACF-6240             Detection of TOMOYO binary (security)
MACF-6242             Status of TOMOYO MAC framework (security)
MACF-6290             Check for implemented MAC framework (security)
MAIL-8802             Check Exim status (security)
MAIL-8804             Exim configuration (security)
MAIL-8814             Check postfix process status (security)
MAIL-8816             Check Postfix configuration (security)
MAIL-8817             Check Postfix configuration errors (security)
MAIL-8818             Postfix banner (security)
MAIL-8820             Postfix configuration (security)
MAIL-8838             Check dovecot process (security)
MAIL-8860             Check Qmail status (security)
MAIL-8880             Check Sendmail status (security)
MAIL-8920             Check OpenSMTPD status (security)
MALW-3274             Check for McAfee VirusScan Command Line Scanner (security)
MALW-3275             Check for chkrootkit (security)
MALW-3276             Check for Rootkit Hunter (security)
MALW-3278             Check for LMD (security)
MALW-3280             Check if anti-virus tool is installed (security)
MALW-3282             Check for clamscan (security)
MALW-3284             Check for clamd (security)
MALW-3286             Check for freshclam (security)
MALW-3288             Check for ClamXav (security)
MALW-3290             Presence of malware scanner (security)
NAME-4016             Check /etc/resolv.conf default domain (security)
NAME-4018             Check /etc/resolv.conf search domains (security)
NAME-4020             Check non default options (security)
NAME-4024  Solaris    Solaris uname -n output (security)
NAME-4026  Solaris    Check /etc/nodename (security)
NAME-4028             Check domain name (security)
NAME-4032             Check nscd status (security)
NAME-4034             Check Unbound status (security)
NAME-4036             Check Unbound configuration file (security)
NAME-4202             Check BIND status (security)
NAME-4204             Search BIND configuration file (security)
NAME-4206             Check BIND configuration consistency (security)
NAME-4210             Check DNS banner (security)
NAME-4230             Check PowerDNS status (security)
NAME-4232             Search PowerDNS configuration file (security)
NAME-4236             Check PowerDNS backends (security)
NAME-4238             Check PowerDNS authoritative status (security)
NAME-4304             Check NIS ypbind status (security)
NAME-4306             Check NIS domain (security)
NAME-4402             Check duplicate line in /etc/hosts (security)
NAME-4404             Check /etc/hosts contains an entry for this server name (security)
NAME-4406             Check server hostname mapping (security)
NAME-4408             Check localhost to IP mapping (security)
NETW-2400             Test hostname for valid characters and length (basics)
NETW-2600  Linux      Checking IPv6 configuration (security)
NETW-2704             Basic nameserver configuration tests (security)
NETW-2705             Check availability two nameservers (security)
NETW-2706             Check DNSSEC status (security)
NETW-3001             Find default gateway (route) (security)
NETW-3004             Search available network interfaces (security)
NETW-3006             Get network MAC addresses (security)
NETW-3008             Get network IP addresses (security)
NETW-3012             Check listening ports (security)
NETW-3014             Checking promiscuous interfaces (BSD) (security)
NETW-3015  Linux      Checking promiscuous interfaces (Linux) (security)
NETW-3028             Checking connections in WAIT state (security)
NETW-3030             Checking DHCP client status (security)
NETW-3032  Linux      Checking for ARP monitoring software (security)
NETW-3200             Determine available network protocols (security)
PHP-2211              Check php.ini presence (security)
PHP-2320              Check PHP disabled functions (security)
PHP-2368              Check PHP register_globals option (security)
PHP-2372              Check PHP expose_php option (security)
PHP-2374              Check PHP enable_dl option (security)
PHP-2376              Check PHP allow_url_fopen option (security)
PHP-2378              Check PHP allow_url_include option (security)
PHP-2379              Check PHP suhosin extension status (security)
PHP-2382              Check PHP listen option (security)
PKGS-7200  Linux      Check Alpine Package Keeper (apk) (security)
PKGS-7301             Query NetBSD pkg (security)
PKGS-7302             Query FreeBSD/NetBSD pkg_info (security)
PKGS-7303             Query brew package manager (security)
PKGS-7304             Querying Gentoo packages (security)
PKGS-7306  Solaris    Querying Solaris packages (security)
PKGS-7308             Checking package list with RPM (security)
PKGS-7310             Checking package list with pacman (security)
PKGS-7312             Checking available updates for pacman based system (security)
PKGS-7314             Checking pacman configuration options (security)
PKGS-7320  Linux      Check presence of arch-audit for Arch Linux (security)
PKGS-7322  Linux      Discover vulnerable packages on Arch Linux (security)
PKGS-7328             Querying Zypper for installed packages (security)
PKGS-7330             Querying Zypper for vulnerable packages (security)
PKGS-7332             Detection of macOS ports and packages (security)
PKGS-7334             Detection of available updates for macOS ports (security)
PKGS-7345             Querying dpkg (security)
PKGS-7346             Search unpurged packages on system (security)
PKGS-7348  FreeBSD    Check for old distfiles (security)
PKGS-7350             Checking for installed packages with DNF utility (security)
PKGS-7352             Checking for security updates with DNF utility (security)
PKGS-7354             Checking package database integrity (security)
PKGS-7366             Checking for debsecan utility (security)
PKGS-7370             Checking for debsums utility (security)
PKGS-7378             Query portmaster for port upgrades (security)
PKGS-7380  NetBSD     Check for vulnerable NetBSD packages (security)
PKGS-7381             Check for vulnerable FreeBSD packages with pkg (security)
PKGS-7382             Check for vulnerable FreeBSD packages with portaudit (security)
PKGS-7383             Check for YUM package Update management (security)
PKGS-7384             Check for YUM utils package (security)
PKGS-7386             Check for YUM security package (security)
PKGS-7387             Check for GPG signing in YUM security package (security)
PKGS-7388             Check security repository in Debian/ubuntu apt sources.list file (security)
PKGS-7390  Linux      Check Ubuntu database consistency (security)
PKGS-7392  Linux      Check for Debian/Ubuntu security updates (security)
PKGS-7393             Check for Gentoo vulnerable packages (security)
PKGS-7394  Linux      Check for Ubuntu updates (security)
PKGS-7395  Linux      Check Alpine upgradeable packages (security)
PKGS-7398             Check for package audit tool (security)
PKGS-7410             Count installed kernel packages (security)
PKGS-7420             Detect toolkit to automatically download and apply upgrades (security)
PRNT-2302  FreeBSD    Check for printcap consistency (security)
PRNT-2304             Check cupsd status (security)
PRNT-2306             Check CUPSd configuration file (security)
PRNT-2307             Check CUPSd configuration file permissions (security)
PRNT-2308             Check CUPSd network configuration (security)
PRNT-2314             Check lpd status (security)
PRNT-2316  AIX        Checking /etc/qconfig file (security)
PRNT-2418  AIX        Checking qdaemon printer spooler status (security)
PRNT-2420  AIX        Checking old print jobs (security)
PROC-3602  Linux      Checking /proc/meminfo for memory details (security)
PROC-3604  Solaris    Query prtconf for memory details (security)
PROC-3612             Check dead or zombie processes (security)
PROC-3614             Check heavy IO waiting based processes (security)
PROC-3802             Check presence of prelink tooling (security)
RBAC-6272             Check grsecurity presence (security)
SCHD-7702             Check status of cron daemon (security)
SCHD-7704             Check crontab/cronjobs (security)
SCHD-7718             Check at users (security)
SCHD-7720             Check at users (security)
SCHD-7724             Check at jobs (security)
SHLL-6202  FreeBSD    Check console TTYs (security)
SHLL-6211             Checking available and valid shells (security)
SHLL-6220             Checking available and valid shells (security)
SHLL-6230             Perform umask check for shell configurations (security)
SINT-7010  MacOS      System Integrity Status (security)
SNMP-3302             Check for running SNMP daemon (security)
SNMP-3304             Check SNMP daemon file location (security)
SNMP-3306             Check SNMP communities (security)
SQD-3602              Check for running Squid daemon (security)
SQD-3604              Check Squid daemon file location (security)
SQD-3606              Check Squid version (security)
SQD-3610              Check Squid version (security)
SQD-3613              Check Squid file permissions (security)
SQD-3614              Check Squid authentication methods (security)
SQD-3616              Check external Squid authentication (security)
SQD-3620              Check Squid access control lists (security)
SQD-3624              Check Squid safe ports (security)
SQD-3630              Check Squid reply_body_max_size option (security)
SQD-3680              Check Squid version suppression (security)
SSH-7402              Check for running SSH daemon (security)
SSH-7404              Check SSH daemon file location (security)
SSH-7406              Detection of OpenSSH server version (security)
SSH-7408              Check SSH specific defined options (security)
SSH-7440              AllowUsers and AllowGroups (security)
STRG-1846  Linux      Check if firewire storage is disabled (security)
STRG-1902             Check rpcinfo registered programs (security)
STRG-1904             Check nfs rpc (security)
STRG-1906             Check nfs rpc (security)
STRG-1920             Checking NFS daemon (security)
STRG-1926             Checking NFS exports (security)
STRG-1928             Checking empty /etc/exports (security)
STRG-1930             Check client access to nfs share (security)
TIME-3104             Check for running NTP daemon or client (security)
TIME-3106             Check systemd NTP time synchronization status (security)
TIME-3112             Check active NTP associations ID's (security)
TIME-3116             Check peers with stratum value of 16 (security)
TIME-3120             Check unreliable NTP peers (security)
TIME-3124             Check selected time source (security)
TIME-3128             Check preffered time source (security)
TIME-3132             Check NTP falsetickers (security)
TIME-3136  Linux      Check NTP protocol version (security)
TIME-3148  Linux      Check TZ variable (performance)
TIME-3160  Linux      Check empty NTP step-tickers (security)
TIME-3170             Check configuration files (security)
TIME-3180             Report if ntpctl cannot communicate with OpenNTPD (security)
TIME-3181             Check status of OpenNTPD time synchronisation (security)
TIME-3182             Check OpenNTPD has working peers (security)
TIME-3185             Check systemd-timesyncd synchronized time (security)
TOOL-5002             Checking for automation tools (security)
TOOL-5102             Check for presence of Fail2ban (security)
TOOL-5104             Enabled tests for Fail2ban (security)
TOOL-5120             Presence of Snort IDS (security)
TOOL-5122             Snort IDS configuration file (security)
TOOL-5130             Check for active Suricata daemon (security)
TOOL-5160             Check for active OSSEC daemon (security)
TOOL-5190             Check presence of available IDS/IPS tooling (security)
USB-1000   Linux      Check if USB storage is disabled (security)
USB-2000   Linux      Check USB authorizations (security)
USB-3000   Linux      Check for presence of USBGuard (security)
```



## 執行

```bash
版本升級
./lynis update info

系統檢測
./lynis audit system

單獨審查
lynis --tests-from-group "group name"

產生的結果會在 /var/log/lynis.log 跟 lynis-report.dat
```

## 分析

```bash
/var/log/lynis.log | grep Warning
/var/log/lynis.log | grep Suggestion
Warning指的是被稽核認為警告的項目, Suggestion則提供建議, 可以做為如何修正問題的參考

核結果中會有許多項目編號, 例如 PKGS-7392、FILE-7524 之類, 若想要查看觀於這個項目的細節, 可以利用指令單獨挑出來看
./lynis show details PKGS-7392
```

## 報表化 (lynis-report-converter)

```bash
wget https://raw.githubusercontent.com/d4t4king/lynis-report-converter/master/lynis-report-converter.pl


想要轉出 HTML 與 XLSX 格式, 需要安裝幾個函式庫
apt install htmldoc
cpan install HTML::HTMLDoc

apt install libxml-writer-perl
apt install libarchive-zip-perl
cpan install Excel::Writer::XLSX

產生HTML
lynis-report-converter.pl -i /var/log/ lynis-report.dat -o ~/lynis.html

產生PDF
lynis-report-converter.pl -i /var/log/ lynis-report.dat -p -o ~/lynis.pdf

產生XLSX
lynis-report-converter.pl –i /var/log/ lynis-report.dat -E -o ~/lynis.xlsx
```

https://www.wangan.com/docs/lynis-1