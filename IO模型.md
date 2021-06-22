# Linux 網路I/O模型說明
```
IO模型描述的是出現I/O等待時進程的狀態以及處理數據的方式
圍繞著進程的狀態, 數據準備到kernel buffer再到app buffer的兩個階段展開
其中數據複製到kernel buffer的過程稱為數據準備階段, 數據從kernel buffer複製到user buffer的過程稱為數據複製階段
對於一個network IO (這裡我們以read舉例), 它會涉及到兩個系統對象,一個是調用這個IO的process (or thread), 另一個就是系統內核(kernel)
當一個read操作發生時, 它會經歷兩個階段：
```
- 等待數據準備 (Waiting for the data to be ready)
- 將數據從內核拷貝到進程中 (Copying the data from the kernel to the process)

這兩點很重要, 因為這些IO Model的區別就是在兩個階段上各有不同的情況

## 5種網路IO模型
```
5種IO模型分別是
-阻塞式IO(Blocking IO)
-非阻塞式IO(NonBlocking IO)
-IO復用(select和poll和epoll)
-信號驅動IO(SIGIO)
-異步IO(POSIX的aio_系列函數)
前4種為同步IO操作 只有異步IO模型是異步(非同步)IO操作
```

![阻塞](IO/Blocking_IO.jpg)


![非阻塞](IO/NonBlocking_IO.jpg)


![復用](IO/復用_IO.jpg)


![信號](IO/信號_IO.jpg)


![異步](IO/非同步_IO.jpg)




- https://www.jianshu.com/p/486b0965c296
- https://www.jianshu.com/p/a99f44d34a69
- https://www.huaweicloud.com/articles/26b1b9fda29be3fb03a51370d373ff49.html
- https://kknews.cc/zh-tw/code/gm9qx38.html
- https://kknews.cc/zh-tw/code/lqkvmg9.html
- https://zhuanlan.zhihu.com/p/88478869
- http://47.97.117.134/jkl/network/io.html


妈妈让我去厨房烧一锅水，准备下饺子
阻塞：水只要没烧开，我就干瞪眼看着这个锅，沧海桑田，日新月异，我自岿然不动，厨房就是我的家，烧水是我的宿命。

非阻塞：我先去我屋子里打把王者，但是每过一分钟，我都要去厨房瞅一眼，生怕时间长了，水烧干了就坏了，这样导致我游戏也心思打，果不然，又掉段了。

同步：不管是每分钟过来看一眼锅，还是寸步不离的一直看着锅，只要我不去看，我就不知道水烧好没有，浪费时间啊，一寸光阴一寸金，这锅必须发我13薪

异步：我在淘宝买了一个电水壶，只要水开了，它就发出响声，嗨呀，可以安心打王者喽，打完可以吃饺子喽~

总结：
阻塞/非阻塞：我在等你干活的时候我在干啥？
阻塞：啥也不干，死等
非阻塞：可以干别的，但也要时不时问问你的进度
同步/异步：你干完了，怎么让我知道呢？
同步：我只要不问，你就不告诉我
异步：你干完了，直接喊我过来就行
