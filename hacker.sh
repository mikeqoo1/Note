#! /bin/bash

# 掃描開啟的port

echo "輸入起始IP(x.x.x.x)"
read FirstIP

echo "輸入結束IP(x)"
read LastIP

echo "輸入要掃描的Port"
read Port

nmap -sT $FirstIP-$LastIP -p $Port >/dev/null -oG Portscan

cat Portscan | grep open > Portscan2

cat Portscan2