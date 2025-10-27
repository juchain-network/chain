#!/bin/bash

# Ju Chain PM2 初始化脚本

echo "🔧 Ju Chain PM2 初始化脚本"
echo "=========================="

# 获取脚本所在目录作为项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 加载环境变量
if [ -f ".env" ]; then
    echo "📋 加载环境变量文件..."
    export $(grep -v '^#' .env | xargs)
    echo "✅ 环境变量加载完成"
else
    echo "⚠️  找不到 .env 文件"
    
    # 检查是否存在 .env.example 文件
    if [ -f ".env.example" ]; then
        echo "📋 发现 .env.example 文件，正在复制为 .env..."
        cp ".env.example" ".env"
        echo "✅ 已创建 .env 文件（从 .env.example 复制）"
        echo "💡 提示：如需自定义配置，请编辑 .env 文件"
        
        # 加载新创建的环境变量文件
        echo "📋 加载环境变量文件..."
        export $(grep -v '^#' .env | xargs)
        echo "✅ 环境变量加载完成"
    else
        echo "❌ 找不到 .env 文件和 .env.example 文件"
        echo "请先创建 .env 配置文件或提供 .env.example 模板文件"
        exit 1
    fi
fi

# 检查并删除 private-chain 目录
if [ -d "./private-chain" ]; then
    echo "🗑️  检测到 private-chain 目录已存在，正在删除..."
    rm -rf "./private-chain"
    echo "✅ private-chain 目录删除完成"
fi

# 检查并删除 ju-logs 目录
if [ -d "./ju-logs" ]; then
    echo "🗑️  检测到 ju-logs 目录已存在，正在删除..."
    rm -rf "./ju-logs"
    echo "✅ ju-logs 目录删除完成"
fi

DATA_DIR="./private-chain/data"
VALIDATOR1_DATA_DIR="./private-chain/data-validator1"
VALIDATOR2_DATA_DIR="./private-chain/data-validator2"
VALIDATOR3_DATA_DIR="./private-chain/data-validator3"
VALIDATOR4_DATA_DIR="./private-chain/data-validator4"
VALIDATOR5_DATA_DIR="./private-chain/data-validator5"
VALIDATOR6_DATA_DIR="./private-chain/data-validator6"
VALIDATOR7_DATA_DIR="./private-chain/data-validator7"
SYNC_DATA_DIR="./private-chain/data-sync"
SYNC_MAINNET_DATA_DIR="./private-chain/data-sync-mainnet"
LOGS_DIR="./logs"
GENESIS_FILE="./genesis.json"
GENESIS_MAINNET_FILE="./genesis-mainet.json"
GETH_BIN="./build/bin/geth"

# 验证者账户信息（从环境变量读取）
VALIDATOR1_PASSWORD_FILE="$VALIDATOR1_DATA_DIR/password.txt"
VALIDATOR2_PASSWORD_FILE="$VALIDATOR2_DATA_DIR/password.txt"
VALIDATOR3_PASSWORD_FILE="$VALIDATOR3_DATA_DIR/password.txt"
VALIDATOR4_PASSWORD_FILE="$VALIDATOR4_DATA_DIR/password.txt"
VALIDATOR5_PASSWORD_FILE="$VALIDATOR5_DATA_DIR/password.txt"
VALIDATOR6_PASSWORD_FILE="$VALIDATOR6_DATA_DIR/password.txt"
VALIDATOR7_PASSWORD_FILE="$VALIDATOR7_DATA_DIR/password.txt"

echo "📁 当前工作目录: $(pwd)"

echo "📁 创建必要的目录..."

# 创建目录
mkdir -p "$DATA_DIR"
mkdir -p "$VALIDATOR1_DATA_DIR"
mkdir -p "$VALIDATOR2_DATA_DIR"
mkdir -p "$VALIDATOR3_DATA_DIR"
mkdir -p "$VALIDATOR4_DATA_DIR"
mkdir -p "$VALIDATOR5_DATA_DIR"
mkdir -p "$VALIDATOR6_DATA_DIR"
mkdir -p "$VALIDATOR7_DATA_DIR"
mkdir -p "$SYNC_DATA_DIR"
mkdir -p "$SYNC_MAINNET_DATA_DIR"
mkdir -p "$LOGS_DIR"
mkdir -p "./ju-logs"

echo "✅ 目录创建完成"

# 检查二进制文件
if [ ! -f "$GETH_BIN" ]; then
    echo "❌ geth 二进制文件不存在，正在编译..."
    make geth
    if [ $? -eq 0 ]; then
        echo "✅ geth 编译成功"
    else
        echo "❌ geth 编译失败"
        exit 1
    fi
fi

# 创建密码文件和导入账户的函数
setup_validator_account() {
    local validator_num=$1
    local data_dir=$2
    local password_file=$3
    local address_var=$4
    local private_key_var=$5
    local password_var=$6
    
    echo "🔑 设置验证者${validator_num}账户..."
    
    # 创建密码文件
    if [ ! -f "$password_file" ]; then
        echo "${!password_var}" > "$password_file"
        if [ "$validator_num" = "6" ]; then
            echo "✅ 候选验证者${validator_num}密码文件已创建"
        else
            echo "✅ 验证者${validator_num}密码文件已创建"
        fi
    fi
    
    # 导入验证者私钥
    existing_account=$($GETH_BIN account list --datadir "$data_dir" 2>/dev/null | grep -i "${!address_var#0x}")
    if [ -n "$existing_account" ]; then
        if [ "$validator_num" = "6" ]; then
            echo "✅ 候选验证者${validator_num}账户已存在"
        else
            echo "✅ 验证者${validator_num}账户已存在"
        fi
    else
        if [ "$validator_num" = "6" ]; then
            echo "📥 导入候选验证者${validator_num}私钥..."
        else
            echo "📥 导入验证者${validator_num}私钥..."
        fi
        TEMP_KEY_FILE="$data_dir/.temp_private_key"
        echo "${!private_key_var}" > "$TEMP_KEY_FILE"
        $GETH_BIN account import --datadir "$data_dir" --password "$password_file" "$TEMP_KEY_FILE"
        rm -f "$TEMP_KEY_FILE"
        if [ "$validator_num" = "6" ]; then
            echo "✅ 候选验证者${validator_num}账户导入成功"
        else
            echo "✅ 验证者${validator_num}账户导入成功"
        fi
    fi
}

# 初始化创世块的函数
init_genesis() {
    local node_type=$1
    local data_dir=$2
    
    if [ ! -d "$data_dir/geth" ]; then
        echo "🔨 初始化${node_type}创世块..."
        $GETH_BIN --datadir "$data_dir" init "$GENESIS_FILE"
        echo "✅ ${node_type}创世块初始化成功"
    fi
}

# 设置五个验证者账户
echo "🔐 开始设置验证者账户..."
setup_validator_account "1" "$VALIDATOR1_DATA_DIR" "$VALIDATOR1_PASSWORD_FILE" "VALIDATOR1_ADDRESS" "VALIDATOR1_PRIVATE_KEY" "VALIDATOR1_PASSWORD"
setup_validator_account "2" "$VALIDATOR2_DATA_DIR" "$VALIDATOR2_PASSWORD_FILE" "VALIDATOR2_ADDRESS" "VALIDATOR2_PRIVATE_KEY" "VALIDATOR2_PASSWORD"
setup_validator_account "3" "$VALIDATOR3_DATA_DIR" "$VALIDATOR3_PASSWORD_FILE" "VALIDATOR3_ADDRESS" "VALIDATOR3_PRIVATE_KEY" "VALIDATOR3_PASSWORD"
setup_validator_account "4" "$VALIDATOR4_DATA_DIR" "$VALIDATOR4_PASSWORD_FILE" "VALIDATOR4_ADDRESS" "VALIDATOR4_PRIVATE_KEY" "VALIDATOR4_PASSWORD"
setup_validator_account "5" "$VALIDATOR5_DATA_DIR" "$VALIDATOR5_PASSWORD_FILE" "VALIDATOR5_ADDRESS" "VALIDATOR5_PRIVATE_KEY" "VALIDATOR5_PASSWORD"
setup_validator_account "6" "$VALIDATOR6_DATA_DIR" "$VALIDATOR6_PASSWORD_FILE" "VALIDATOR6_ADDRESS" "VALIDATOR6_PRIVATE_KEY" "VALIDATOR6_PASSWORD"
setup_validator_account "7" "$VALIDATOR7_DATA_DIR" "$VALIDATOR7_PASSWORD_FILE" "VALIDATOR7_ADDRESS" "VALIDATOR7_PRIVATE_KEY" "VALIDATOR7_PASSWORD"
echo "✅ 所有验证者账户设置完成"

# 初始化 mainnet 同步节点的创世块
init_mainnet_genesis() {
    local node_type=$1
    local data_dir=$2
    local genesis_file=$3
    
    if [ ! -d "$data_dir/geth" ]; then
        echo "🔨 初始化${node_type}创世块..."
        $GETH_BIN --datadir "$data_dir" init "$genesis_file"
        echo "✅ ${node_type}创世块初始化成功"
    else
        echo "✅ ${node_type}创世块已存在，跳过初始化"
    fi
}

# 初始化所有节点的创世块
echo "🔨 开始初始化创世块..."
init_genesis "验证者1节点" "$VALIDATOR1_DATA_DIR"
init_genesis "验证者2节点" "$VALIDATOR2_DATA_DIR"  
init_genesis "验证者3节点" "$VALIDATOR3_DATA_DIR"
init_genesis "验证者4节点" "$VALIDATOR4_DATA_DIR"
init_genesis "验证者5节点" "$VALIDATOR5_DATA_DIR"
init_genesis "候选验证者6节点" "$VALIDATOR6_DATA_DIR"
init_genesis "候选验证者7节点" "$VALIDATOR7_DATA_DIR"
init_genesis "同步节点" "$SYNC_DATA_DIR"

# 初始化 mainnet 同步节点的创世块
echo "🌐 初始化 mainnet 同步节点..."
if [ ! -f "$GENESIS_MAINNET_FILE" ]; then
    echo "❌ 找不到 mainnet 创世文件: $GENESIS_MAINNET_FILE"
    exit 1
fi

init_mainnet_genesis "mainnet同步节点" "$SYNC_MAINNET_DATA_DIR" "$GENESIS_MAINNET_FILE"

echo "✅ 所有节点创世块初始化完成"

echo ""
echo "🌐 获取并更新节点 enode 地址..."

# 函数：获取节点 enode 地址
get_node_enode() {
    local datadir=$1
    local port=$2
    local node_name=$3
    
    echo "🔍 获取 ${node_name} enode 地址..." >&2
    
    # 使用不同的端口避免冲突
    local temp_port=$((port + 20000))
    local temp_http_port=$((temp_port + 1000))
    
    # 启动节点并从日志中提取enode
    local log_file="/tmp/geth_${temp_port}.log"
    ./build/bin/geth --datadir "$datadir" --port "$temp_port" --http.port "$temp_http_port" --http --http.api "admin" --http.addr "127.0.0.1" --nodiscover > "$log_file" 2>&1 &
    local geth_pid=$!
    
    # 等待节点启动并监控日志
    local count=0
    local node_id=""
    while [ $count -lt 10 ] && [ -z "$node_id" ]; do
        sleep 1
        if [ -f "$log_file" ]; then
            node_id=$(grep "Started P2P networking" "$log_file" | grep -o 'enode://[^@]*' | cut -d'/' -f3 | head -1)
        fi
        count=$((count + 1))
    done
    
    # 停止节点并清理
    kill $geth_pid 2>/dev/null
    wait $geth_pid 2>/dev/null
    rm -f "$log_file"
    
    if [ -n "$node_id" ]; then
        echo "enode://${node_id}@127.0.0.1:${port}"
    else
        echo ""
    fi
}

# 获取各个验证者节点的 enode
echo "🚀 获取验证者节点 enode 地址..."

VALIDATOR1_ENODE=$(get_node_enode "./private-chain/data-validator1" "$VALIDATOR1_P2P_PORT" "验证者1")
VALIDATOR2_ENODE=$(get_node_enode "./private-chain/data-validator2" "$VALIDATOR2_P2P_PORT" "验证者2") 
VALIDATOR3_ENODE=$(get_node_enode "./private-chain/data-validator3" "$VALIDATOR3_P2P_PORT" "验证者3")
VALIDATOR4_ENODE=$(get_node_enode "./private-chain/data-validator4" "$VALIDATOR4_P2P_PORT" "验证者4")
VALIDATOR5_ENODE=$(get_node_enode "./private-chain/data-validator5" "$VALIDATOR5_P2P_PORT" "验证者5")
VALIDATOR6_ENODE=$(get_node_enode "./private-chain/data-validator6" "$VALIDATOR6_P2P_PORT" "候选验证者6")
VALIDATOR7_ENODE=$(get_node_enode "./private-chain/data-validator7" "$VALIDATOR7_P2P_PORT" "候选验证者7")

# 如果获取失败，重试一次
if [ -z "$VALIDATOR1_ENODE" ] || [ -z "$VALIDATOR2_ENODE" ] || [ -z "$VALIDATOR3_ENODE" ] || [ -z "$VALIDATOR4_ENODE" ] || [ -z "$VALIDATOR5_ENODE" ] || [ -z "$VALIDATOR6_ENODE" ] || [ -z "$VALIDATOR7_ENODE" ]; then
    echo "⚠️  部分 enode 获取失败，重试..."
    sleep 2
    
    [ -z "$VALIDATOR1_ENODE" ] && VALIDATOR1_ENODE=$(get_node_enode "./private-chain/data-validator1" "$VALIDATOR1_P2P_PORT" "验证者1")
    [ -z "$VALIDATOR2_ENODE" ] && VALIDATOR2_ENODE=$(get_node_enode "./private-chain/data-validator2" "$VALIDATOR2_P2P_PORT" "验证者2")
    [ -z "$VALIDATOR3_ENODE" ] && VALIDATOR3_ENODE=$(get_node_enode "./private-chain/data-validator3" "$VALIDATOR3_P2P_PORT" "验证者3")
    [ -z "$VALIDATOR4_ENODE" ] && VALIDATOR4_ENODE=$(get_node_enode "./private-chain/data-validator4" "$VALIDATOR4_P2P_PORT" "验证者4")
    [ -z "$VALIDATOR5_ENODE" ] && VALIDATOR5_ENODE=$(get_node_enode "./private-chain/data-validator5" "$VALIDATOR5_P2P_PORT" "验证者5")
    [ -z "$VALIDATOR6_ENODE" ] && VALIDATOR6_ENODE=$(get_node_enode "./private-chain/data-validator6" "$VALIDATOR6_P2P_PORT" "候选验证者6")
    [ -z "$VALIDATOR7_ENODE" ] && VALIDATOR7_ENODE=$(get_node_enode "./private-chain/data-validator7" "$VALIDATOR7_P2P_PORT" "候选验证者7")
fi

# 显示获取到的 enode
echo ""
echo "📋 获取到的 enode 地址："
[ -n "$VALIDATOR1_ENODE" ] && echo "验证者1: $VALIDATOR1_ENODE"
[ -n "$VALIDATOR2_ENODE" ] && echo "验证者2: $VALIDATOR2_ENODE"
[ -n "$VALIDATOR3_ENODE" ] && echo "验证者3: $VALIDATOR3_ENODE"
[ -n "$VALIDATOR4_ENODE" ] && echo "验证者4: $VALIDATOR4_ENODE"
[ -n "$VALIDATOR5_ENODE" ] && echo "验证者5: $VALIDATOR5_ENODE"
[ -n "$VALIDATOR6_ENODE" ] && echo "候选验证者6: $VALIDATOR6_ENODE"
[ -n "$VALIDATOR7_ENODE" ] && echo "候选验证者7: $VALIDATOR7_ENODE"

# 更新配置文件的函数 - 使用更安全的方法
update_static_nodes() {
    local config_file=$1
    local exclude_enode=$2
    
    # 构建静态节点列表（排除自己）
    local static_nodes=""
    [ -n "$VALIDATOR1_ENODE" ] && [ "$VALIDATOR1_ENODE" != "$exclude_enode" ] && static_nodes="$static_nodes\"$VALIDATOR1_ENODE\", "
    [ -n "$VALIDATOR2_ENODE" ] && [ "$VALIDATOR2_ENODE" != "$exclude_enode" ] && static_nodes="$static_nodes\"$VALIDATOR2_ENODE\", "
    [ -n "$VALIDATOR3_ENODE" ] && [ "$VALIDATOR3_ENODE" != "$exclude_enode" ] && static_nodes="$static_nodes\"$VALIDATOR3_ENODE\", "
    [ -n "$VALIDATOR4_ENODE" ] && [ "$VALIDATOR4_ENODE" != "$exclude_enode" ] && static_nodes="$static_nodes\"$VALIDATOR4_ENODE\", "
    [ -n "$VALIDATOR5_ENODE" ] && [ "$VALIDATOR5_ENODE" != "$exclude_enode" ] && static_nodes="$static_nodes\"$VALIDATOR5_ENODE\", "
    [ -n "$VALIDATOR6_ENODE" ] && [ "$VALIDATOR6_ENODE" != "$exclude_enode" ] && static_nodes="$static_nodes\"$VALIDATOR6_ENODE\", "
    [ -n "$VALIDATOR7_ENODE" ] && [ "$VALIDATOR7_ENODE" != "$exclude_enode" ] && static_nodes="$static_nodes\"$VALIDATOR7_ENODE\", "
    
    # 移除最后的逗号和空格
    static_nodes=$(echo "$static_nodes" | sed 's/, $//')
    
    if [ -n "$static_nodes" ] && [ -f "$config_file" ]; then
        echo "🔧 更新 $config_file 中的 StaticNodes..."
        
        # 设置环境变量并使用Python脚本来安全地更新TOML文件，避免破坏结构
        export STATIC_NODES_CONTENT="$static_nodes"
        python3 << EOF
import re
import sys
import os

config_file = "$config_file"

try:
    with open(config_file, 'r') as f:
        content = f.read()
    
    # 从环境变量读取静态节点内容，避免字符串转义问题
    static_nodes_content = os.environ.get('STATIC_NODES_CONTENT', '')
    
    if not static_nodes_content:
        print(f"⚠️  没有静态节点内容可更新")
        sys.exit(0)
    
    # 使用正则表达式精确匹配和替换StaticNodes
    # 匹配 StaticNodes = [...] 可能跨多行
    pattern = r'(StaticNodes\s*=\s*\[)[^\]]*(\])'
    replacement = r'\1' + static_nodes_content + r'\2'
    
    updated_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    if updated_content != content:
        with open(config_file, 'w') as f:
            f.write(updated_content)
        print(f"✅ 已更新 {config_file} 的静态节点配置")
    else:
        print(f"⚠️  在 {config_file} 中未找到 StaticNodes 配置或无需更新")
    
except Exception as e:
    print(f"❌ 更新 {config_file} 时出错: {e}")
    sys.exit(1)
EOF
    else
        if [ -z "$static_nodes" ]; then
            echo "⚠️  没有可用的静态节点配置"
        elif [ ! -f "$config_file" ]; then
            echo "❌ 配置文件 $config_file 不存在"
        fi
    fi
}

# 更新所有配置文件
if [ -n "$VALIDATOR1_ENODE" ] || [ -n "$VALIDATOR2_ENODE" ] || [ -n "$VALIDATOR3_ENODE" ] || [ -n "$VALIDATOR4_ENODE" ] || [ -n "$VALIDATOR5_ENODE" ] || [ -n "$VALIDATOR6_ENODE" ] || [ -n "$VALIDATOR7_ENODE" ]; then
    echo ""
    echo "🔧 更新配置文件中的静态节点..."
    
    update_static_nodes "./config-validator1.toml" "$VALIDATOR1_ENODE"
    update_static_nodes "./config-validator2.toml" "$VALIDATOR2_ENODE"
    update_static_nodes "./config-validator3.toml" "$VALIDATOR3_ENODE"
    update_static_nodes "./config-validator4.toml" "$VALIDATOR4_ENODE"
    update_static_nodes "./config-validator5.toml" "$VALIDATOR5_ENODE"
    update_static_nodes "./config-validator6.toml" "$VALIDATOR6_ENODE"
    update_static_nodes "./config-validator7.toml" "$VALIDATOR7_ENODE"
    update_static_nodes "./config-syncnode.toml" ""
    
    echo ""
    echo "🔍 验证配置文件结构..."
    
    # 验证配置文件结构的函数
    validate_config_structure() {
        local config_file=$1
        local file_name=$(basename "$config_file")
        
        echo "验证 $file_name..."
        
        # 检查是否有错误的字段位置
        local errors=()
        
        # 更精确地检查 [Node.P2P] 部分是否包含不应该存在的字段
        # 使用 awk 来精确检查节点部分内容
        local p2p_section=$(awk '/^\[Node\.P2P\]/{flag=1; next} /^\[/{flag=0} flag' "$config_file")
        
        if echo "$p2p_section" | grep -q "^\s*\(DataDir\|KeyStoreDir\|NetworkId\|SyncMode\)\s*=" 2>/dev/null; then
            errors+=("⚠️  发现字段在错误的 [Node.P2P] 部分")
        fi
        
        # 检查必要的部分是否存在
        if ! grep -q "^\[Node\]" "$config_file" 2>/dev/null; then
            errors+=("⚠️  缺少 [Node] 部分")
        fi
        
        if ! grep -q "^\[Node\.P2P\]" "$config_file" 2>/dev/null; then
            errors+=("⚠️  缺少 [Node.P2P] 部分")
        fi
        
        if ! grep -q "^\[Eth\]" "$config_file" 2>/dev/null; then
            errors+=("⚠️  缺少 [Eth] 部分")
        fi
        
        # 检查关键字段是否在正确的位置
        local node_section=$(awk '/^\[Node\]$/{flag=1; next} /^\[/{flag=0} flag' "$config_file")
        local eth_section=$(awk '/^\[Eth\]$/{flag=1; next} /^\[/{flag=0} flag' "$config_file")
        
        if ! echo "$node_section" | grep -q "DataDir" 2>/dev/null; then
            errors+=("⚠️  [Node] 部分缺少 DataDir 字段")
        fi
        
        if ! echo "$eth_section" | grep -q "NetworkId" 2>/dev/null; then
            errors+=("⚠️  [Eth] 部分缺少 NetworkId 字段")
        fi
        
        if [ ${#errors[@]} -eq 0 ]; then
            echo "✅ $file_name 结构正确"
        else
            echo "❌ $file_name 存在结构问题:"
            printf '%s\n' "${errors[@]}"
            return 1
        fi
        
        return 0
    }
    
    # 验证所有配置文件
    validate_config_structure "./config-validator1.toml"
    validate_config_structure "./config-validator2.toml"
    validate_config_structure "./config-validator3.toml"
    validate_config_structure "./config-validator4.toml"
    validate_config_structure "./config-validator5.toml"
    validate_config_structure "./config-validator6.toml"
    validate_config_structure "./config-validator7.toml"
    validate_config_structure "./config-syncnode.toml"
    
    echo "✅ 所有配置文件静态节点已更新"
else
    echo "⚠️  无法获取到有效的 enode 地址，请手动配置静态节点"
fi

echo ""
echo "✅ PM2 初始化完成！"
echo ""
echo "📋 下一步操作："
echo "1. 启动所有节点: ./pm2-manager.sh"
echo "   或直接使用: pm2 start ecosystem.config.js"
echo "2. 查看节点状态: pm2 status"
echo "3. 查看日志: pm2 logs"
echo ""
echo "🔗 节点信息："
echo "验证者1节点: http://localhost:${VALIDATOR1_HTTP_PORT} (WebSocket: ${VALIDATOR1_WS_PORT})"
echo "验证者2节点: http://localhost:${VALIDATOR2_HTTP_PORT} (WebSocket: ${VALIDATOR2_WS_PORT})"
echo "验证者3节点: http://localhost:${VALIDATOR3_HTTP_PORT} (WebSocket: ${VALIDATOR3_WS_PORT})"
echo "验证者4节点: http://localhost:${VALIDATOR4_HTTP_PORT} (WebSocket: ${VALIDATOR4_WS_PORT})"
echo "验证者5节点: http://localhost:${VALIDATOR5_HTTP_PORT} (WebSocket: ${VALIDATOR5_WS_PORT})"
echo "候选验证者6节点: http://localhost:${VALIDATOR6_HTTP_PORT} (WebSocket: ${VALIDATOR6_WS_PORT})"
echo "候选验证者7节点: http://localhost:${VALIDATOR7_HTTP_PORT} (WebSocket: ${VALIDATOR7_WS_PORT})"
echo "同步节点: http://localhost:${SYNCNODE_HTTP_PORT} (WebSocket: ${SYNCNODE_WS_PORT})"
echo "Mainnet同步节点: http://localhost:${SYNCNODE_MAINNET_HTTP_PORT:-8549} (WebSocket: ${SYNCNODE_MAINNET_WS_PORT:-8550})"
echo ""
echo "📍 验证者地址："
echo "验证者1: ${VALIDATOR1_ADDRESS}"
echo "验证者2: ${VALIDATOR2_ADDRESS}"
echo "验证者3: ${VALIDATOR3_ADDRESS}"
echo "验证者4: ${VALIDATOR4_ADDRESS}"
echo "验证者5: ${VALIDATOR5_ADDRESS}"
echo "候选验证者6: ${VALIDATOR6_ADDRESS}"
echo "候选验证者7: ${VALIDATOR7_ADDRESS}"
echo ""
echo "🌐 网络连接："
if [ -n "$VALIDATOR1_ENODE" ] || [ -n "$VALIDATOR2_ENODE" ] || [ -n "$VALIDATOR3_ENODE" ] || [ -n "$VALIDATOR4_ENODE" ] || [ -n "$VALIDATOR5_ENODE" ] || [ -n "$VALIDATOR6_ENODE" ] || [ -n "$VALIDATOR7_ENODE" ]; then
    echo "- 已自动配置验证者节点静态连接"
    [ -n "$VALIDATOR1_ENODE" ] && echo "  验证者1: $(echo $VALIDATOR1_ENODE | cut -d'@' -f2)"
    [ -n "$VALIDATOR2_ENODE" ] && echo "  验证者2: $(echo $VALIDATOR2_ENODE | cut -d'@' -f2)"
    [ -n "$VALIDATOR3_ENODE" ] && echo "  验证者3: $(echo $VALIDATOR3_ENODE | cut -d'@' -f2)"
    [ -n "$VALIDATOR4_ENODE" ] && echo "  验证者4: $(echo $VALIDATOR4_ENODE | cut -d'@' -f2)"
    [ -n "$VALIDATOR5_ENODE" ] && echo "  验证者5: $(echo $VALIDATOR5_ENODE | cut -d'@' -f2)"
    [ -n "$VALIDATOR6_ENODE" ] && echo "  候选验证者6: $(echo $VALIDATOR6_ENODE | cut -d'@' -f2)"
    [ -n "$VALIDATOR7_ENODE" ] && echo "  候选验证者7: $(echo $VALIDATOR7_ENODE | cut -d'@' -f2)"
    echo "- 节点启动后将自动建立 P2P 连接"
else
    echo "- 本地测试网络节点配置为点对点直连模式"
    echo "- 验证者节点将直接发现并连接到其他验证者"
fi
echo "- Testnet 同步节点使用本地验证者节点连接"
echo "- Mainnet 同步节点使用独立的静态节点连接到主网络"
echo "  Mainnet 节点端口: ${SYNCNODE_MAINNET_P2P_PORT:-30312}"
echo "  Mainnet 网络 ID: ${MAINNET_NETWORK_ID:-210000}"
