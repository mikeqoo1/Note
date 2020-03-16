# 其他項目

## Node.js

nvm install
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

nvm install --lts

```

## Clang-Format格式化教學

在vscode 上使用 C/C++ 的排版功能
```
Clang-Format可用格式化多種不同語言的code, 排版格式主要有：LLVM, Google, Chromium, Mozilla, WebKit

選項設定
打開設定（ctrl + ,）搜索format 

勾選format on save 自動保存


C_Cpp: Clang_format_style 決定格式化形式, 如果是file, 則是使用在workspace中的.clang-format


C_Cpp: Clang_format_fallback Style, 如果上面的選項是file, 但是沒有.clang-format文件

處理方法
終端機中输入

clang-format -style=5種格式選一個 -dump-config > .clang-format
```
