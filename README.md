# palette
利用聚类进行图片之间的迁移，方便快速对 RM 的图块进行调色。

程序由 ocra 打包成 exe 可执行文件。
```
ocra --no-autoload --output palette.exe main.rb
```

# How to use
请下载 [palette.zip](https://github.com/gxm11/palette/releases/download/release/palette.zip)，解压后双击`palette.exe`执行。
1. 若同目录下没有配置文件`palette.json`，程序会创建此文件并退出。
2. 若配置文件`palette.json`已经存在，程序会根据配置开始迁移图片。
3. 在运行过程中，每处理一份子图，都会保存到硬盘上，方便随时查看。
4. 在运行过程中，随时都可以使用 Ctrl+C 重新开始。

# Config
## train
key | introduction 
:--:|:-------------
from|训练时使用的初始文件（原始风格）
to|训练时使用的目标文件（新风格）
cluster|聚类分析的结果保存位置
episodes|训练次数
max_cluster_number|最大的聚类数量，不能小于 2
weights|各项特征的权重

## convert
key | introduction
:--:|:-------------
from|需要进行转换的文件（原始风格）
to|转换后的文件保存位置（新风格）
x_split|文件在横向上的子图数
y_split|文件在纵向上的子图数
