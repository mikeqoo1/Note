ADMIN="E-Mail"

# 設定空間使用達10%通知
ALERT=10

#定出不需要檢查的FileSystem，中間用「|」隔開，以下為不檢查/dev/sda1及/dev/sda2
ExceptionalPartition="/dev/sdb1|/dev/sdb2"

#因df -H第一列是TITLE，所以awk完後使用grep -v 'Use%'過濾掉第一列TITLE列
df  -H | grep -vE $ExceptionalPartition | awk '{ print $5 " " $6 }' | grep -v 'Use%' | while read output;
do
      usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1 )
      partition=$(echo $output | awk '{ print $2 }' )
      if [ $usep -ge $ALERT ]; then
            echo -ne "SOS! SOS! SOS! \n out of space \"$partition ($usep%)\" on $(hostname) as on $(date)" | mail -s "Warning: out of disk space $usep %" $ADMIN
      fi
done