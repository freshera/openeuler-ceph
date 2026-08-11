########################################
############编译打包grpc#################
########################################

# 1. 安装依赖
dnf install -y rpm-build rpmdevtools cmake gcc-c++ \
  protobuf-devel protobuf-compiler protobuf-lite-devel \
  openssl-devel c-ares-devel gtest-devel zlib-devel gperftools-devel \
  re2-devel abseil-cpp-devel \
  python3-devel python3-setuptools python3-Cython

# 2. 下载源码,替换spec文件
rm -rf ~/rpmbuild 
cd ~
rpmdev-setuptree
#dnf download --source grpc
wget https://dl-cdn.openeuler.openatom.cn/openEuler-24.03-LTS-SP4/source/Packages/grpc-1.60.0-5.oe2403sp4.src.rpm
rpm -ivh grpc-1.60.0-*.src.rpm
rm -rf ~/rpmbuild/SPECS/grpc.spec
cd -
cp ./grpc.spec ~/rpmbuild/SPECS/

# 3. 编译打包
rpmbuild -ba ~/rpmbuild/SPECS/grpc.spec

# 4. 检查cmake
rpm -qlp ~/rpmbuild/RPMS/$(uname -m)/grpc-devel-1.60.0-5.1*.rpm | grep gRPCConfig
