########################################
############编译打包grpc################
########################################

# 1. 下载grpc源码
git clone -b v1.60.0 --depth 1 https://github.com/gilfoylegpt/grpc.git
cd grpc
git switch -c v1.60.0
git submodule update --init --recursive
# git push --set-upstream origin refs/heads/v1.60.0
# git pull --set-upstream origin refs/heads/v1.60.0

