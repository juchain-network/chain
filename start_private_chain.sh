#!/bin/bash

# AAC 私有链启动脚本 (Congress 共识)

echo "🚀 AAC 私有链启动脚本 (Congress POA)"
echo "=================================="

# 设置变量
CHAIN_DIR="/Users/enty/ju-chain-work/chain"
DATA_DIR="/Users/enty/ju-chain-work/chain/private-chain/data"
GENESIS_FILE="/Users/enty/ju-chain-work/genesis.json"
GETH_BIN="$CHAIN_DIR/build/bin/geth"
          
echo "📁 项目目录: $CHAIN_DIR"
echo "💾 数据目录: $DATA_DIR"
echo "🔧 Genesis 文件: $GENESIS_FILE"
echo "⚙️  共识算法: Congress (POA)"
echo "⏱️  出块间隔: 3 秒"
echo "🔄 验证者更新周期: 200 块"

# 检查 geth 是否存在
if [ ! -f "$GETH_BIN" ]; then
    echo "❌ geth 二进制文件不存在，请先编译"
    echo "运行: cd $CHAIN_DIR && make geth"
    exit 1
fi

echo "✅ geth 二进制文件存在"

# 检查验证者账户是否存在
VALIDATOR_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
PASSWORD_FILE="$DATA_DIR/password.txt"

if [ ! -f "$PASSWORD_FILE" ]; then
    echo "❌ 验证者账户未设置，请先运行:"
    echo "   ./setup_validator.sh"
    exit 1
fi

# 检查账户是否已导入
account_exists=$($GETH_BIN account list --datadir "$DATA_DIR" 2>/dev/null | grep -i "${VALIDATOR_ADDRESS#0x}")
if [ -z "$account_exists" ]; then
    echo "❌ 验证者账户未导入，请先运行:"
    echo "   ./setup_validator.sh"
    exit 1
fi

echo "✅ 验证者账户已设置"

# 创建数据目录
mkdir -p "$DATA_DIR"
echo "✅ 数据目录已创建"

# 初始化创世块（如果尚未初始化）
if [ ! -d "$DATA_DIR/geth" ]; then
    echo "🔨 初始化创世块..."
    $GETH_BIN --datadir "$DATA_DIR" init "$GENESIS_FILE"
    if [ $? -eq 0 ]; then
        echo "✅ 创世块初始化成功"
    else
        echo "❌ 创世块初始化失败"
        exit 1
    fi
else
    echo "✅ 创世块已存在，跳过初始化"
fi

echo ""
echo "🎯 启动选项："
echo "1. 启动验证者节点（Congress 挖矿）"
echo "2. 启动普通节点（不参与共识）"
echo "3. 只显示命令，不启动"
echo ""

read -p "请选择 (1-3): " choice

case $choice in
    1)
        echo "🔥 启动验证者节点 (Congress POA)..."
        echo "验证者账户: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        echo "HTTP RPC: http://localhost:8545"
        echo "WebSocket: ws://localhost:8546"
        echo "P2P 端口: 30303"
        echo "⚠️  注意: 此账户已配置为初始验证者"
        echo ""
        
        $GETH_BIN \
            --datadir "$DATA_DIR" \
            --networkid 202599 \
            --http \
            --http.addr "0.0.0.0" \
            --http.port 8545 \
            --http.api "eth,net,web3,personal,admin,miner,congress" \
            --http.corsdomain "*" \
            --ws \
            --ws.addr "0.0.0.0" \
            --ws.port 8546 \
            --ws.api "eth,net,web3,personal,admin,miner,congress" \
            --ws.origins "*" \
            --port 30303 \
            --mine \
            --miner.etherbase "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
            --password "$DATA_DIR/password.txt" \
            --unlock "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
            --allow-insecure-unlock \
            --verbosity 4 \
            --maxpeers 50 \
            --syncmode "full" \
            --gcmode "archive"
        ;;
    2)
        echo "� 启动普通节点 (Congress POA)..."
        echo "不参与共识的只读节点"
        echo "HTTP RPC: http://localhost:8545"
        echo "WebSocket: ws://localhost:8546"
        echo ""
        
        $GETH_BIN \
            --datadir "$DATA_DIR" \
            --networkid 202599 \
            --http \
            --http.addr "0.0.0.0" \
            --http.port 8545 \
            --http.api "eth,net,web3,personal,admin,congress" \
            --http.corsdomain "*" \
            --ws \
            --ws.addr "0.0.0.0" \
            --ws.port 8546 \
            --ws.api "eth,net,web3,personal,admin,congress" \
            --ws.origins "*" \
            --port 30303 \
            --verbosity 3 \
            --maxpeers 50 \
            --syncmode "full"
        ;;
    3)
        echo "📋 Congress POA 启动命令："
        echo ""
        echo "验证者节点："
        echo "$GETH_BIN \\"
        echo "    --datadir \"$DATA_DIR\" \\"
        echo "    --networkid 202599 \\"
        echo "    --http --http.addr \"0.0.0.0\" --http.port 8545 \\"
        echo "    --http.api \"eth,net,web3,personal,admin,miner,congress\" \\"
        echo "    --http.corsdomain \"*\" \\"
        echo "    --ws --ws.addr \"0.0.0.0\" --ws.port 8546 \\"
        echo "    --ws.api \"eth,net,web3,personal,admin,miner,congress\" \\"
        echo "    --ws.origins \"*\" \\"
        echo "    --port 30303 \\"
        echo "    --mine \\"
        echo "    --miner.etherbase \"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266\" \\"
        echo "    --password \"$DATA_DIR/password.txt\" \\"
        echo "    --unlock \"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266\" \\"
        echo "    --allow-insecure-unlock \\"
        echo "    --verbosity 4 \\"
        echo "    --maxpeers 50 \\"
        echo "    --syncmode \"full\" \\"
        echo "    --gcmode \"archive\""
        echo ""
        echo "普通节点："
        echo "$GETH_BIN \\"
        echo "    --datadir \"$DATA_DIR\" \\"
        echo "    --networkid 202599 \\"
        echo "    --http --http.addr \"0.0.0.0\" --http.port 8545 \\"
        echo "    --http.api \"eth,net,web3,personal,admin,congress\" \\"
        echo "    --http.corsdomain \"*\" \\"
        echo "    --ws --ws.addr \"0.0.0.0\" --ws.port 8546 \\"
        echo "    --ws.api \"eth,net,web3,personal,admin,congress\" \\"
        echo "    --ws.origins \"*\" \\"
        echo "    --port 30303 \\"
        echo "    --verbosity 3 \\"
        echo "    --maxpeers 50 \\"
        echo "    --syncmode \"full\""
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "🔗 实用连接信息："
echo "📊 HTTP RPC: http://localhost:8545"
echo "🌐 WebSocket: ws://localhost:8546"
echo "🆔 Chain ID: 202599"
echo "👤 验证者账户: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "🏛️ 系统合约地址:"
echo "   - Validators: 0x000000000000000000000000000000000000f000"
echo "   - Punish: 0x000000000000000000000000000000000000f001"
echo "   - Proposal: 0x000000000000000000000000000000000000f002"
echo ""
echo "💡 查询 Congress 状态:"
echo "curl -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"congress_getCurrentValidators\",\"params\":[],\"id\":1}' http://localhost:8545"
