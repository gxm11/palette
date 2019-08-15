# palette
利用聚类进行图片之间的迁移，方便快速对 RM 的图块进行调色。

程序由 ocra 打包成 exe 可执行文件。
```
ocra --debug-extract --output palette.exe main.rb
```

# How to use
## Windows
请下载 [palette.exe](https://github.com/gxm11/palette/releases/latest/download/palette.exe)，放置在主目录下执行。
1. 配置文件`palette.json`已经存在于工程主目录中，程序会读取配置开始执行。
2. 若同目录下没有配置文件`palette.json`，程序会创建此文件并退出，请修改后再次执行。
3. 在运行过程中，每处理一份子图，都会保存到`debug`文件夹里，方便随时查看。
4. 在运行过程中，随时都可以使用 Ctrl+C 重新开始。

## Linux or WSL
1. Install gems: `gem install chunky_png parallel`
2. Run main.rb: `ruby main.rb` or `ruby main.rb <path/to/config>`

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
*threads|可选参数，同时执行的线程数，在 Linux 下会以多进程执行。默认会自动采取并行方案。

## Weights
每个像素点根据其坐标和颜色被编码成 6 维的向量：`[X, Y, R, G, B, A]`。而权重用于计算两个像素点之间的距离：
```
dv = v1 - v2
distance = dv' * W * dv
```
这意味着，如果在指定的方向上像素点的变化越严重，就越需要增大权重。

# Methods
## train
1. 从`from`中随机选取`max_cluster_number`个像素点作为聚类中心
2. 执行**K-means**方法，如果一个聚类里没有任何元素，它将被舍弃
3. 如此即可把`from`中全部像素点划分成若干个类别，称为 `clusters = {cluster_center, cluster_points}`

## convert
1. 划分图片为`x_split * y_split`个子图片
2. 处理每一个子图片上的每一个不透明的点，假设是点`p`。
3. 获取离它最近的聚类中心`c`，在此聚类中寻找距离点`p`最近的点`q`，`q`是`from`上的一个点
4. 将点`p`染上`to`图片中`q`对应的位置的颜色
5. 拼合图片
