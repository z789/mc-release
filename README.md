# mc-rpm

## 背景：
       系统中有一个稳定、可靠的基础安全机制，上层安全才容易做。
       Linux中的强制访问控制selinux、apparmor等都非常优秀，但配置比较复杂，掌握使用都比较困难，在很多场景下都是关闭的	      。而且都没有运行时验证执行代码(NIST sp800-167)。
       Iot、云的发展，安全出现新的问题，如勒索、挖矿、rootkit、定制化的攻击、间谍软件、非已知的恶意软件、网络空间军事对抗。
       需要能简单使用的防御手段：应用程序的白名单，即运行时验证文件的签名。

## 原则：
    1. 简单。容易理解，实现简单、使用简单.
    2. 高性能。
    3. 不求全面。通过规划、定制规则，满足多数场景即可。

## 一点安全理论：
    hash验证是否发生改变，签名验证来源。在特殊场景下，需要验证多重签名。但一个签名即可满足多数场景，签名中包含完整性验证。


## 系统中执行的文件及执行方式有以下几类：
    A.  ELF格式的可执行、so库、有特征头的脚本，并且直接执行。 
        c/c++、 go等编译性程序都是编译成ELF文件进行执行。 有特征头的shell、perl等脚本。
    B.  解释执行的程序，被执行文件是格式化的。 例如 java 执行的文件是jar或者class格式， 这些文件都是有魔数的。
    C.  解释执行的程序，被执行文件是文本且有特征头。 例如 bash ./i.sh, i.sh 文件中有#!/bin/bash。
    D.  解释执行的程序，被执行文件是文本但没有特征头。 例如 bash ./i, i文件中没有#!/bin/bash。
    E.  解释执行的程序, 会把原始文件编译成中间文件，然后可以从中间文件执行。例如 python先把py文件编译成 pyc文件。

    A类文件强制验证签名
    B类文件魔数匹配的验证签名，其他文件不验证
    C类和B类处理相同
    D类文件，根据文件的mime类型，mime类型匹配的验证. 可以自定义mime类型
    E类和B类处理相同


## 系统由以下几部分组成：
    1. 打上补丁的内核。
    2. 目录/proc/sys/kernel/mc/下的接口。这些接口可以进行配置、查看策略，查看性能统计信息等等。
    3. 一些应用层工具，主要包含：一些签名的工具, 接收MC内核日志，并进行动作的精灵进程。


## 解释类程序的配置规则格式。 编译性程序不需要配置，强制验证签名。

    ADD/DEL     interp           MAGIC/MIME/EPATH/*             [offset magic_word]/[mime_type VERIFY|SKIP]/[epath]...
     动作       解释器路径     配置是[魔数/mime/忽略路径]的关键字                 相应配置的具体内容

    ADD/DEL interp MAGIC [[offset magic_word] [offset magic_word] ... ]    //给解释器配置解释文件的魔数
    ADD/DEL interp MIME  [mime_type VERIFY|SKIP]                           //给解释器配置解释文件的mime类型
    ADD/DEL interp EPATH [epath]                                           //给解释器配置忽略的文件或者路径 
    ADD/DEL interp DEFAULT [ACCEPT|REJECT]                                 //给解释器配置默认策略
    ADD/DEL interp *                                                       //强制验证解释器解释、打开的文件
    上面配置命令里大写的是关键字，关键字不区分大小写，但一般大写以示区别。

   配置规则是向 /proc/sys/kernel/mc/set_interp_rule写入规则. 例如：
echo 'add /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.322.b06-2.el8_5.x86_64/jre/bin/java magic 0 504b0304140008' >/proc/sys/kernel/mc/set_interp_rule

例子
- java config：
```
      ADD interp DEFAULT [ACCEPT]
      ADD interp MAGIC [offset magic_word]
```

- python config:
    ```
    ADD interp MAGIC [offset magic_word]
    ADD interp MIME  [mime_type VERIFY|SKIP]
    ADD interp DEFAULT [REJECT]
    ```

- shell config:
    ```
    ADD interp MAGIC [offset magic_word]
    ADD interp MIME  [mime_type VERIFY|SKIP]
    ADD interp EPATH [epath]
    ADD interp DEFAULT [REJECT]
    ```


## 安装与使用：
    安装新内核:
      在centos8 stream上安装内核 kernel-5.15.5mc-81.x86_64.rpm:  sudo rpm -ivh kernel-5.15.5mc-81.x86_64.rpm

    安装应用程序: 
     1. 解压安装包  sudo tar -C / -zxvf mctool.tgz
     2. 对系统进行基础签名、设置mime。（测试版本的私钥使用内核模块签名的私钥，正式版本中是独立的私钥和证书）
        sudo /usr/local/bin/mc-sign-mime-tool -sm sha512 /etc/mc/mc_key.pem /etc/mc/mc_key.x509 /
     3. 重启系统，使用新内核， 执行sudo /usr/local/bin/mc-logd -dc /var/log/mclog 启动日志精灵进程。 
        或者把/usr/local/bin/mc-logd -dc /var/log/mclog写入rc.local文件，随系统启动。 
        sudo /usr/local/bin/mc-logd -dc /var/log/mclog

## mc相关配置目录和文件
### /proc/sys/kernel/mc 目录：
    该目录是配置、查看统计信息等的入口。 该目录下有以下文件：
    enable                             //启用、禁用MC功能。 默认是1，表示启用。
    enforce                            //mc是否强制模式。   默认是0, 表示不强制，但记录日志。如果系统已经进行基础签名并启动mclog, 可
                                       //设置成1，此时，签名验证错误时则拒绝执行。
    file_format                        //需要验证的执行文件格式集合。   一般不改变该文件值。
    filename_max_cost                  //统计信息， 验证签名花费时间最大的文件名字，与max_cost对应。
    interp_rules                       //查询解释器的配置。
    log_user                           //mc日志发送到应用层 或者内核中打印。 默认是0, 表示内核中打印，mc-logd启动时，则设置为1。
    max_cost                           //统计信息， 验证签名花费的最大时间。 单位是jiffie。
    max_file_size                      //验证签名的文件最大尺寸，单位字节。默认是314572800，表示300M。
    num_exe_ima                        //验证编译性程序的数量。
    num_interp_ima                     //为了验证解释性程序，open、mmap、read的数量。
    num_lib_ima                        //验证so库的数量。
    set_interp_rule                    //配置解释器规则的入口。
    total_cost                         //mc系统总共花费的时间，单位jiffie。
    match_interp_label                 //按照解释器的路径、标记匹配。 如果设置1, 则按照标记匹配，interp_rules相应的规则也应是主体的标记
    alg_name  avail_alg                //这两个文件是计算主体标记的hash算法和可利用算法，默认是sha256. 一般不需要改变该文件值。

### /etc/mc 配置文件目录
    /etc/mc/mc_key.pem /etc/mc/mc_key.x509   //签名时私钥和证书
    /etc/mc/interp.conf                      //设置文件mime的配置文件

    /etc/mc/profile/                         //该目录下是解释器的配置脚本。分为两类，一类是按照解释器的绝对路径，另一类是按照解释器的标记
                                            （标记是解释器的sha256sum)。mc-logd根据启动选项自动选择执行相应的脚本，默认是按照解释器的绝对路径。


## 建议：
    1. 没对系统做基础签名、设置mime前，先禁用MC，不然会产生大量日志。 
    2. 总体安全性，取决于对系统的了解程度、对规则的配置精细程度。
    3. 设计适合自己的mime系统，能配置更好的规则，消耗更少的时间。
    4. 优先配置MAGIC规则，其次是MIME规则，最后是忽略路径EPATH规则。 
      epath尽量少使用，如果使用，尽量精确到文件。如果能设计适合自己的mime系统，完全可以不用epath。

## 参考
   魔数：https://filesignatures.net/index.php?page=all 或者file 源码的 magic目录
   mime-type: file 源码的 magic目录

