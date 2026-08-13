#!/bin/bash
##############################################
## openEuler 24.03 编译 nfs-ganesha V7.3
## 适配欧拉源：关闭grpc、移除不存在grpc依赖包
## 打包阶段清理python缓存/egg，减少unpackaged文件告警
## 启用FSAL_CEPH/FSAL_VFS/FSAL_XFS
##############################################
set -euo pipefail

# 1. 配置Ceph 20.2.3本地源并安装开发库
echo "===== [1] 配置 Ceph 20.2.3 本地源 ====="
rm -f /etc/yum.repos.d/ceph-20.2.3-euler.repo
cat > /etc/yum.repos.d/ceph-20.2.3-euler.repo << 'REPOEOF'
[ceph-20.2.3-euler]
name=ceph-20.2.3-euler - $basearch
baseurl=http://10.20.81.5/yum/ceph/ceph-20.2.3-euler/$basearch/
gpgcheck=0
priority=1
REPOEOF
dnf install -y dnf-plugins-core 2>/dev/null || true
dnf config-manager --set-priority=1 ceph-20.2.3-euler 2>/dev/null || true
dnf makecache

# 安装Ceph开发依赖
dnf install -y --repo=ceph-20.2.3-euler libcephfs-devel librados-devel librgw-devel

# 校验Ceph运行库与开发库版本一致性
CEPHFS_RT_VER=$(rpm -q libcephfs2 2>/dev/null | sed 's/libcephfs2-//')
CEPHFS_DEV_VER=$(rpm -q libcephfs-devel 2>/dev/null | sed 's/libcephfs-devel-//')
if [ -n "${CEPHFS_RT_VER}" ] && [ -n "${CEPHFS_DEV_VER}" ]; then
  RT_MAJOR=$(echo ${CEPHFS_RT_VER} | cut -d- -f1)
  DEV_MAJOR=$(echo ${CEPHFS_DEV_VER} | cut -d- -f1)
  if [ "${RT_MAJOR}" != "${DEV_MAJOR}" ]; then
    echo "ERROR: Ceph runtime与devel包版本不匹配，终止执行"
    exit 1
  fi
fi

# 2. 安装编译依赖 + RPM打包工具（已删除grpc相关不存在包）
echo "===== [2] 安装编译及RPM打包依赖 ====="
dnf install -y git cmake gcc gcc-c++ make ninja-build autoconf automake libtool bison flex doxygen pkgconfig \
python3 python3-devel openssl-devel krb5-devel libuuid-devel nfs-utils userspace-rcu-devel \
dbus-devel dbus-c++-devel libnsl2-devel libtirpc-devel libnl3-devel libcap-devel libblkid-devel \
audit-libs-devel protobuf-devel protobuf-c protobuf-c-devel libacl-devel \
libmount-devel json-c-devel systemd-devel rpm-build rpmlint tar xz createrepo \
doxygen libxslt xmlto rpmdevtools

# 3. 拉取nfs-ganesha V7.3源码
echo "===== [3] 拉取nfs-ganesha V7.3源码 ====="
export http_proxy=http://22.129.24.90:10808
export https_proxy=http://22.129.24.90:10808
mkdir -p /usr/local/src
cd /usr/local/src
rm -rf /usr/local/src/nfs-ganesha
git clone --recursive -b V7.3 https://github.com/nfs-ganesha/nfs-ganesha.git
cd /usr/local/src/nfs-ganesha
git submodule update --init --recursive
unset http_proxy https_proxy

# 4. CMake编译配置（关闭grpc、关闭AUNAFS）
echo "===== [4] CMake参数配置 ====="
rm -rf /usr/local/src/nfs-ganesha/build
mkdir -p /usr/local/src/nfs-ganesha/build
cd /usr/local/src/nfs-ganesha/build
cmake ../src \
  -GNinja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DSYSCONF_INSTALL_DIR=/etc \
  -DRPMBUILD_ROOT=${HOME}/rpmbuild \
  -DGANESHA_VERSION_NUM=7.3 \
  -DUSE_GRPC=OFF \
  -DUSE_FSAL_CEPH=ON \
  -DBUILD_DOCUMENTATION=ON \
  -DUSE_FSAL_RGW=OFF \
  -DUSE_FSAL_VFS=ON \
  -DUSE_FSAL_LUSTRE=OFF \
  -DUSE_FSAL_GPFS=OFF \
  -DUSE_FSAL_GLUSTER=OFF \
  -DUSE_FSAL_XFS=ON \
  -DUSE_FSAL_AUNAFS=OFF \
  -DUSE_DBUS=ON \
  -DUSE_9P=OFF \
  -DUSE_ADMIN_TOOLS=ON \
  -DUSE_RQUOTA=ON \
  -DUSE_GSS=ON \
  -DUSE_SYSTEM_NTIRPC=OFF \
  -DCEPH_INCLUDE_DIR=/usr/include \
  -DCEPH_LIBDIR=/usr/lib64 \
  -DRADOS_INCLUDE_DIR=/usr/include \
  -DRADOS_LIBDIR=/usr/lib64 \
  -DRGW_INCLUDE_DIR=/usr/include \
  -DRGW_LIBDIR=/usr/lib64

# 5. 编译二进制
echo "===== [5] 开始编译源码 ====="
ninja -j$(nproc)

# ====================== 修复RPM打包逻辑（移除手动解压重打包，避免tar损坏） ======================
echo "===== [6] 生成干净源码tar包并校验完整性 ====="
# 生成源码包
ninja package_source
TAR_FILE="/usr/local/src/nfs-ganesha/build/nfs-ganesha-7.3.tar.gz"
# 校验tar包是否完整可用
if ! tar -tzf "${TAR_FILE}" >/dev/null; then
  echo "ERROR: tar包损坏，重新生成package_source"
  rm -f "${TAR_FILE}"
  ninja package_source
  if ! tar -tzf "${TAR_FILE}" >/dev/null; then
    echo "FATAL: 多次生成tar包仍损坏，终止脚本"
    exit 1
  fi
fi
echo "tar包校验通过，开始构建rpm"

echo "===== 清理旧rpmbuild缓存 ====="
rm -rf ~/rpmbuild
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# 移动源码压缩包到rpmbuild SOURCES目录
mv -f "${TAR_FILE}" ~/rpmbuild/SOURCES/
TAR_FILE=~/rpmbuild/SOURCES/nfs-ganesha-7.3.tar.gz
echo "源码包已移动至：${TAR_FILE}"
SPEC_FILE=~/rpmbuild/SPECS/nfs-ganesha-7.3.spec

# 直接从压缩包取出已经生成好的nfs‑ganesha.spec
tar -Oxzf "${TAR_FILE}" nfs-ganesha-7.3/nfs-ganesha.spec > "${SPEC_FILE}"

if [ ! -s "${SPEC_FILE}" ];then
    echo "ERROR: 提取spec失败"
    exit 1
fi
echo "spec已提取：${SPEC_FILE}"

# 修改依赖包的版本
sed -i 's/libcephfs-devel >= 10.2.0/libcephfs-devel >= v20.3.2/' "${SPEC_FILE}"
sed -i 's/librados-devel >= 0.61/librados-devel >= v20.3.2/' "${SPEC_FILE}"

# 修改RPM包版本号
sed -i 's/^Version:\s*7\.3$/Version:\t7.3.ideal.oe2403sp4/' "${SPEC_FILE}"

# 修改spec文件，增加如下信息 745 行
#%{python3_sitelib}/ganesha_top-*.egg
#%{_libexecdir}/ganesha/__pycache__/*.pyc
#%{_libdir}/ganesha/libfsalsaunafs.so
sed -i '900d' "${SPEC_FILE}"
sed -i '747a\%{python3_sitelib}/ganesha_top-*.egg\n%{_libexecdir}/ganesha/__pycache__/*.pyc' "${SPEC_FILE}"
sed -i '747a\%{_libdir}/ganesha/libfsalsaunafs.so' "${SPEC_FILE}"

rpmbuild -ba "${SPEC_FILE}"


# 归集所有rpm包到统一输出目录
rm -rf /opt/ganesha-rpm-output
mkdir -p /opt/ganesha-rpm-output
find ~/rpmbuild -type f -name "*.rpm" -exec cp {} /opt/ganesha-rpm-output/ \;
echo "====================================="
echo "所有RPM包已复制至 /opt/ganesha-rpm-output"
ls -lh /opt/ganesha-rpm-output/*.rpm
echo "====================================="
# =================================================================