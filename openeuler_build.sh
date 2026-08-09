##############################################
##在openeuler 24.03环境编译ceph，并制作出rpm包
##############################################

# 安装基础包
dnf install -y git g++ python3 python3-devel python3-pip rpm-build npm
dnf update -y


# 解决openeuler没有python命令的问题
ln -s /usr/bin/python3 /usr/bin/python

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
pip3 install jsonnet asyncssh


# 源码文件转化
yum install -y dos2unix && find . | xargs dos2unix

# 安装 libnbd-devel，暂时用rocky9的
export base_arch="`arch`"
wget http://10.20.81.5/yum/rocky9/${base_arch}/crb/Packages/l/libnbd-devel-1.20.2-2.el9.${base_arch}.rpm
wget http://10.20.81.5/yum/rocky9/${base_arch}/appstream/Packages/l/libnbd-1.20.2-2.el9.${base_arch}.rpm
rpm -ivh libnbd-devel-1.20.2-2.el9.${base_arch}.rpm libnbd-1.20.2-2.el9.${base_arch}.rpm
rm -rf libnbd-devel-1.20.2-2.el9.${base_arch}.rpm libnbd-1.20.2-2.el9.${base_arch}.rpm

# 安装依赖包（适配openeuler）
chmod a+x *.sh
chmod a+x cmake/modules/*.sh
chmod a+x -R */*.sh */*/*.sh
chmod a+x make-dist
./install-deps.sh


# 使用cmake编译
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
rm -rf build
./do_cmake.sh

# 源码编译和安装
cd build
ninja -j64
ninja install

# 编译出rpm包
cd ../
rm -rf ceph-srpm
cp -r openeuler-ceph ceph-srpm
cd ceph-srpm
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
./make-srpm.sh v20.3.2

# 编译出rpm安装包
rm -rf /root/rpmbuild/*
mkdir -p /root/rpmbuild/{SPECS,SOURCES}
cp ceph-v20.3.2.tar.bz2  /root/rpmbuild/SOURCES
cp ceph.spec  /root/rpmbuild/SPECS
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
rpmbuild -ba /root/rpmbuild/SPECS/ceph.spec

#####################################################
# run-make-check开发人员用来做完整编译 + 单元测试 + 格式检查
# 完整性验证通过，再继续后续的编译和打包操作
####################################################
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
rm -rf build
./run-make-check.sh