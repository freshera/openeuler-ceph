##############################################
##在openeuler 24.03环境编译ceph，并制作出rpm包
##############################################

# 安装基础包
dnf install -y git

# 设置github代理
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
# 下载ceph源码
git clone https://github.com/freshera/openeuler-ceph
cd openeuler-ceph
git checkout v20.2.3
git switch -c v20.2.3 origin/v20.2.3

export http_proxy=
export https_proxy=
# 补齐python依赖（测试用）
dnf install -y python3-pip
pip3 install jsonnet asyncssh

# 安装依赖包（适配openeuler）
./install-deps.sh

# make之前的检查，并拉相关依赖代码
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
./run-make-check.sh

# 使用cmake编译
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
./do_cmake.sh

# 编译出rpm包
./make-srpm.sh