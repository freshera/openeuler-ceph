##############################################
##在openeuler 24.03环境编译ceph，并制作出rpm包
##############################################

# 设置github代理
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808

# 下载ceph源码
git clone https://github.com/freshera/openeuler-ceph
cd openeuler-ceph
git checkout v20.2.3

# 安装依赖包（适配openeuler）
./install-deps.sh