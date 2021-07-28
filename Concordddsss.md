# 康x技能包

## 憑證問題

```bash
先把IE的憑證匯出來, ??????.cer

上網 處理方法
sudo cp ??????.cer /etc/ssl/certs

npm 處理方法
npm config set cafile "/path/??????.cer"

snap 處理方法
openssl x509 -inform der -in ??????.cer -out xxxx.pem
sudo snap set system store-certs.cert1="$(cat /path/xxxx.pem)"
```
