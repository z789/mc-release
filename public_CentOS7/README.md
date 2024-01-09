# mc-rpm

## 背景：
    系统中有一个稳定、可靠的基础安全机制，上层安全才容易做。

    Linux中的强制访问控制selinux、apparmor等都非常优秀，但配置比较复杂，掌握使用都比较困难，
    在很多场景下都是关闭的。而且都没有运行时验证执行代码(NIST sp800-167)。

    Iot、云的发展，安全出现新的问题，如病毒、勒索、挖矿、rootkit、定制化的攻击、间谍软件、
    非已知的恶意软件、网络空间军事对抗。

    需要能简单使用的防御手段：可执行代码白名单，即运行时验证文件的签名。

## 原则：
    1. 简单。容易理解，实现简单、使用简单.
    2. 高性能。
    3. 不求全面。通过规划、定制规则，满足多数场景即可。

## 一点安全理论：
    hash验证是否发生改变，签名验证来源。在特殊场景下，需要验证多重签名。
    但一个签名即可满足多数场景，签名中包含完整性验证。


## 系统中执行的文件及执行方式有以下几类：
    A.  ELF格式的可执行、so库、有特征头的脚本，并且直接执行。 
        c/c++、 go等编译性程序都是编译成ELF文件进行执行。 有特征头的shell、perl等脚本。
    B.  解释执行的程序，被执行文件是格式化的。 例如 java 执行的文件是jar或者class格式，
        这些文件都是有魔数的。
    C.  解释执行的程序，被执行文件是文本且有特征头。 例如 bash ./i.sh, i.sh 文件中有#!/bin/bash。
    D.  解释执行的程序，被执行文件是文本但没有特征头。 例如 bash ./i, i文件中没有#!/bin/bash。
    E.  解释执行的程序, 会把原始文件编译成中间文件，然后可以从中间文件执行。
        例如 python先把py文件编译成 pyc文件。

    A类文件强制验证签名
    B类文件魔数匹配的验证签名，其他文件不验证
    C类和B类处理相同
    D类文件，根据文件的mime类型，mime类型匹配的验证. 可以自定义mime类型
    E类和B类处理相同


## 系统由以下几部分组成：
    1. 打上补丁的内核。
    2. 目录/proc/sys/kernel/mc/下的接口。这些接口可以进行配置、查看策略，
       查看性能统计信息等等。
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

    配置规则是向 /proc/sys/kernel/mc/set_interp_rule写入规则. 例如:
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
