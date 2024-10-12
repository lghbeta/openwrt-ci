#!/bin/bash

read -r -p "是否仅测试编译？输[y]仅输出配置文件，输[n]执行完整编译? [Y/n] " input

#仅输出配置文件
case $input in
    [yY][eE][sS]|[yY])
        export WRT_TEST='true'
        ;;
    [nN][oO]|[nN])
        export WRT_TEST='false'
        ;;
    *)
        echo "无效输入."
        exit 1
        ;;
esac

#目标平台
export WRT_TARGET=IPQ-JDC
#默认主题
export WRT_THEME=argon
#默认主机名
export WRT_NAME=OpenWrt
#默认WIFI名
export WRT_WIFI=OpenWrt
#默认地址
export WRT_IP=192.168.1.1
#默认密码，仅作提示，修改无用
export WRT_PW=无

#源码名称
export WRT_SOURCE=VIKINGYFY/immortalwrt
#源码链接
export WRT_REPO=https://github.com/"$WRT_SOURCE".git
#源码分支
export WRT_BRANCH=main
#附加插件(仅限一个)
export WRT_PACKAGE=

#CI工作目录
export GITHUB_WORKSPACE=$(pwd)
export WRT_DATE=$(TZ=UTC-8 date +"%y%m%d_%H%M")
export WRT_CI=$(basename $GITHUB_WORKSPACE)
export WRT_VER=$(echo $WRT_REPO | cut -d '/' -f 5-)-$WRT_BRANCH
export WRT_TYPE=$(sed -n "1{s/^#//;s/\r$//;p;q}" $GITHUB_WORKSPACE/Config/$WRT_TARGET.txt)

export SRC_DIR=$GITHUB_WORKSPACE/wrt
export RELEASE_DIR="$SRC_DIR"/release/"$WRT_DATE"

echo -e "\n=================================================================================="
lscpu | grep -E "name|Core|Thread"
echo "=================================================================================="
df -h
echo "=================================================================================="
echo 源码：$WRT_REPO:$WRT_BRANCH
echo 平台：$WRT_TARGET
echo 设备：$WRT_TYPE
echo 地址：$WRT_IP
echo 密码：$WRT_PW
echo -e "==================================================================================\n"

#下载编译源码
echo -e "\n>>> Checkout Repo...\n"
if [ "$(ls -A $SRC_DIR)" = "" ] || [ ! -d "$SRC_DIR" ]; then
    git clone --depth=1 --single-branch --branch $WRT_BRANCH $WRT_REPO $SRC_DIR
fi

#源码清理重置
cd $SRC_DIR
git fetch --all && git reset --hard HEAD && git pull --force
export WRT_HASH=$(git log -1 --pretty=format:'%h')

if [ -d "$SRC_DIR"/feeds/luci ]; then
    cd "$SRC_DIR"/feeds/luci
    git fetch --all && git reset --hard HEAD && git pull --force
fi

#执行脚本
echo -e "\n>>> Apply patches...\n"
cd $GITHUB_WORKSPACE
#转换行符&增加可执行权限
#find ./ -maxdepth 3 -type f -iregex ".*\(txt\|sh\)$" -exec dos2unix {} \; -exec chmod +x {} \;
if [ -f "$GITHUB_WORKSPACE/Patches/Patches.sh" ]; then
    $GITHUB_WORKSPACE/Patches/Patches.sh
else
    echo "No patches need to be installed!"
fi

#下载源码
echo -e "\n>>> Install feeds & packages...\n"
cd $SRC_DIR
./scripts/feeds update -a && ./scripts/feeds install -a

#自定义包
cd $SRC_DIR/package/
$GITHUB_WORKSPACE/Scripts/Packages.sh
$GITHUB_WORKSPACE/Scripts/Handles.sh

#自定义配置
echo -e "\n>>> Generate configuration...\n"
cd $SRC_DIR/
rm -rf ./tmp* ./.config*
cat $GITHUB_WORKSPACE/Config/$WRT_TARGET.txt $GITHUB_WORKSPACE/Config/GENERAL.txt >> .config
$GITHUB_WORKSPACE/Scripts/Settings.sh
make defconfig

#下载工具链
if [[ $WRT_TEST != 'true' ]]; then
    echo -e "\n>>> Download dl libraries...\n"
    cd $SRC_DIR
    make download -j$(nproc)
fi

#编译
if [[ $WRT_TEST != 'true' ]]; then
    echo -e "\n>>> Compile firmware...\n"
    cd $SRC_DIR
    make -j$(nproc) || make -j1 V=s
fi

#发布
cd $SRC_DIR && mkdir -p $RELEASE_DIR
cp -f ./.config "$RELEASE_DIR"/Config_"$WRT_TARGET"_"$WRT_VER"_"$WRT_DATE".txt

if [[ $WRT_TEST != 'true' ]]; then
    echo -e "\n>>> Release firmware to $RELEASE_DIR...\n"
    find ./bin/targets/ -iregex ".*\(packages\)$" -exec rm -rf {} +

    for TYPE in $WRT_TYPE ; do
        for FILE in $(find ./bin/targets/ -type f -iname "*$TYPE*.*") ; do
            EXT=$(basename $FILE | cut -d '.' -f 2-)
            NAME=$(basename $FILE | cut -d '.' -f 1 | grep -io "\($TYPE\).*")
            NEW_FILE="$WRT_VER"_"$NAME"_"$WRT_DATE"."$EXT"
            mv -f $FILE "$RELEASE_DIR"/$NEW_FILE
        done
    done

    find ./bin/targets/ -type f -exec mv -f {} "$RELEASE_DIR"/ \;
fi

