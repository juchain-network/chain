#!/bin/bash

# AAC 链编译脚本

echo "🔨 AAC 链编译脚本"
echo "================="

# 检查 Go 版本
echo "📋 Go 版本信息:"
go version

# 检查当前目录
if [ ! -f "go.mod" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

echo ""
echo "🚀 开始编译..."

# 清理之前的构建
echo "🧹 清理之前的构建..."
make clean

# 更新依赖
echo "📦 整理依赖..."
go mod tidy

# 编译 geth
echo "🔨 编译 geth..."
make geth

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 编译成功！"
    echo "📁 二进制文件位置: ./build/bin/"
    echo ""
    echo "📋 可用命令:"
    ls -la ./build/bin/
    echo ""
    echo "🔧 测试 geth:"
    ./build/bin/geth version
    echo ""
    echo "🚀 要启动私有链，请运行:"
    echo "   ./start_private_chain.sh"
else
    echo "❌ 编译失败"
    exit 1
fi
