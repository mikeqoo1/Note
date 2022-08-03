# Lynis Linux的資安檢測工具

## 安裝

```bash
git clone https://github.com/CISOfy/lynis

使用sudo的root權限的話, 記得先 sudo chown -R 0:0 lynis, 才不會有權限問題
```

## 執行

```bash
版本升級
./lynis update info

系統檢測
./lynis audit system

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
lynis-report-converter.pl -i  /var/log/ lynis-report.dat -p -o ~/lynis.pdf

產生XLSX
lynis-report-converter.pl –i /var/log/ lynis-report.dat -E -o ~/lynis.xlsx
```
