#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_CI-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
if [[ $WRT_TARGET == *"IPQ"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
fi

#My Config
if [[ $WRT_TARGET == *"IPQ"* && $WRT_SOURCE == *"VIKINGYFY"* ]]; then
	echo "CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y" >> ./.config
fi
echo "CONFIG_PACKAGE_luci-app-passwall=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=n" >> ./.config

#修改菜单
sed -i 's/"UPnP IGD & PCP\/NAT-PMP"/"UPnP"/g' $(find ./feeds/luci/applications/luci-app-upnp/ -type f -name "luci-app-upnp.json")
#sed -i ':a;N;s/msgid "Wake on LAN +"\s*msgstr ""/msgid "Wake on LAN +"\nmsgstr "网络唤醒+"/g;ta' $(find ./package/luci-app-wolplus/po/zh_Hans/wolplus.po)

#添加初始运行脚本
mkdir -p files/etc/uci-defaults && cat << "EOF" > files/etc/uci-defaults/99-init-settings
#!/bin/bash

# Change source feeds
sed -i "s/^[^#].*qualcommax\/ipq60xx.*/#&/g" /etc/opkg/distfeeds.conf
sed -i "/nss_packages/d;/sqm_scripts_nss/d" /etc/opkg/distfeeds.conf

# Set default theme to luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# Disable IPV6 ula prefix
#sed -i 's/^[^#].*option ula/#&/' /etc/config/network
#uci set network.globals.ula_prefix=''
#uci commit network

# Enable flow offloading(Not required when using nss driver)
#uci set firewall.@defaults[0].flow_offloading=1
#uci set firewall.@defaults[0].flow_offloading_hw=1
#uci commit firewall

# System config
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].conloglevel='4'
uci set system.@system[0].cronloglevel='8'
uci delete system.ntp.server
uci add_list system.ntp.server='ntp.aliyun.com'
uci add_list system.ntp.server='ntp.ntsc.ac.cn'
uci add_list system.ntp.server='cn.pool.ntp.org'
uci add_list system.ntp.server='pool.ntp.org'
#uci set system.@system[0].zram_size_mb='100'
uci commit system

# Wireless config
#uci set wireless.radio0.country='CN'
#uci set wireless.radio0.channel='44'
#uci set wireless.radio0.txpower='20'
#uci commit wireless

exit 0
EOF