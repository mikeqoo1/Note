# Elastic簡介

### Elastic特點

一個分散式搜尋分析系統, 除了資料庫功能外, 還有base on Apache Lucene為基礎建置的<font color="#dd0000">開放原始碼, 分散式, RESTful</font>的檢索架構, 還具有高度的<font color="#dd0000">可擴充性(scalability)與可用性(availability)</font>


### ELK?

ELK Stack 是指 Elasticsearch, Logstash和Kibana 這三個Open Source軟體的集合套件

- Elasticsearch：核心資料庫是NOSQL的一種, 但跟一般NOSQL的資料庫比較不一樣的地方, Elasticsearch是透過JSON的方式來進行所有的CRUD(select, insert, update, delete)操作與設定
- Logstash：收集各式各樣的Log或是資訊, 並且根據你的Log來Parser成你要的資料欄位 
- Kibana：視覺化與圖形化的方式來顯示各種Log, 可以透過Elasticsearch資料庫來建立
- Beats：針對特定要收集的Log, 官方量身定做的輕量級日誌收集與轉送套件, 目前的Beats有Filebeat, Packetbeat, Winlogbeat, Metricbeat, Heartbeat, Auditbeat等, 跟Logstash 功能差不多, 但只能單純的轉送Log無法像Logstash一樣自訂Parser

### 名詞

```
----------------------------
RDBMS        | ElasticSearch
Server       | Node
DB           | Index
Table        | Type
Primary key  | Id
Row          | Document
Column       | Field
Schema       | Mapping
----------------------------
```

### 參考

- https://its-security.blogspot.com/2018/02/introduction-elasticsearch.html

- https://godleon.github.io/blog/Elasticsearch/Elasticsearch-getting-started/

- https://godleon.github.io/blog/