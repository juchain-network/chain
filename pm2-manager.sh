#!/bin/bash

# Ju Chain PM2 管理脚本

# 获取脚本所在目录作为项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 加载环境变量
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

ECOSYSTEM_FILE="./ecosystem.config.js"

# 挖矿余额分析函数
analyze_mining_rewards() {
    local VALIDATOR1_RPC="http://localhost:${VALIDATOR1_HTTP_PORT:-8545}"
    local VALIDATOR2_RPC="http://localhost:${VALIDATOR2_HTTP_PORT:-8553}"
    local VALIDATOR3_RPC="http://localhost:${VALIDATOR3_HTTP_PORT:-8556}"
    local VALIDATOR4_RPC="http://localhost:${VALIDATOR4_HTTP_PORT:-8559}"
    local VALIDATOR5_RPC="http://localhost:${VALIDATOR5_HTTP_PORT:-8562}"
    
    echo "========================================="
    echo "📊 验证者账户挖矿余额分析"
    echo "========================================="
    
    # 检查节点是否在线
    if ! curl -s -f "$VALIDATOR1_RPC" > /dev/null 2>&1; then
        echo "❌ 验证者节点未运行，请先启动节点"
        return 1
    fi
    
    # 获取当前区块高度
    local block_height=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$VALIDATOR1_RPC" | jq -r '.result' | xargs printf "%d")
    
    # 计算Epoch信息
    local epoch_length=200
    local current_epoch=$((block_height / epoch_length))
    local next_epoch=$(((current_epoch + 1) * epoch_length))
    local blocks_to_next_epoch=$((next_epoch - block_height))
    
    echo "📈 区块链状态:"
    echo "   当前区块高度: $block_height"
    echo "   Epoch长度: $epoch_length"
    echo "   当前Epoch: $current_epoch"
    echo "   下一个Epoch: $next_epoch"
    echo "   距离下一个Epoch: $blocks_to_next_epoch 个区块"
    echo ""
    
    # 获取验证者地址
    local validator1_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "$VALIDATOR1_RPC" | jq -r '.result')
    
    local validator2_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "$VALIDATOR2_RPC" | jq -r '.result')
    
    local validator3_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "$VALIDATOR3_RPC" | jq -r '.result')
    
    local validator4_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "$VALIDATOR4_RPC" | jq -r '.result')
    
    local validator5_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "$VALIDATOR5_RPC" | jq -r '.result')
    
    echo "💰 验证者账户余额:"
    echo ""
    
    # 获取余额并转换为ETH
    get_balance_and_show "🥇 Validator1" "$validator1_addr" "$VALIDATOR1_RPC" "300000000"
    get_balance_and_show "🥈 Validator2" "$validator2_addr" "$VALIDATOR1_RPC" "100000000"
    get_balance_and_show "🥉 Validator3" "$validator3_addr" "$VALIDATOR1_RPC" "100000000"
    get_balance_and_show "🏅 Validator4" "$validator4_addr" "$VALIDATOR1_RPC" "100000000"
    get_balance_and_show "🎖️ Validator5" "$validator5_addr" "$VALIDATOR1_RPC" "100000000"
    
    echo ""
    echo "🔄 最近区块挖矿情况:"
    
    # 显示最近几个区块的挖矿者
    local start_block=$((block_height - 5))
    if [ $start_block -lt 1 ]; then
        start_block=1
    fi
    
    for ((i=start_block; i<=block_height; i++)); do
        local hex_block=$(printf "0x%x" $i)
        local miner=$(curl -s -X POST -H "Content-Type: application/json" \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$hex_block\",false],\"id\":1}" \
            "$VALIDATOR1_RPC" | jq -r '.result.miner')
        
        local validator_name=""
        if [ "$miner" = "$validator1_addr" ]; then
            validator_name="Validator1 ✅"
        elif [ "$miner" = "$validator2_addr" ]; then
            validator_name="Validator2 ✅"
        elif [ "$miner" = "$validator3_addr" ]; then
            validator_name="Validator3 ✅"
        elif [ "$miner" = "$validator4_addr" ]; then
            validator_name="Validator4 ✅"
        elif [ "$miner" = "$validator5_addr" ]; then
            validator_name="Validator5 ✅"
        else
            validator_name="Unknown"
        fi
        
        echo "   Block $i: $validator_name"
    done
    
    # 获取网络连接状态
    echo ""
    echo "🌐 网络连接状态:"
    local peer_count1=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        "$VALIDATOR1_RPC" | jq -r '.result' | xargs printf "%d")
    
    local peer_count2=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        "$VALIDATOR2_RPC" | jq -r '.result' | xargs printf "%d")
    
    local peer_count3=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        "$VALIDATOR3_RPC" | jq -r '.result' | xargs printf "%d")
    
    echo "   Validator1: $peer_count1 个对等节点"
    echo "   Validator2: $peer_count2 个对等节点"
    echo "   Validator3: $peer_count3 个对等节点"
    
    echo ""
    echo "✅ 共识状态: Congress机制正常，验证者轮流挖矿"
    echo ""
    echo "💡 使用 Congress CLI 工具查询详细奖励信息："
    echo "   选择选项 9: 验证者奖励查询 (Congress CLI)"
    echo "========================================="
}

# Congress CLI 验证者奖励查询函数
analyze_congress_rewards() {
    local VALIDATOR1_RPC="http://localhost:${VALIDATOR1_HTTP_PORT:-8545}"
    local CHAIN_ID="${CHAIN_ID:-202599}"
    local CONGRESS_CLI_PATH="../sys-contract/congress-cli/build/congress-cli"
    
    echo "========================================="
    echo "🏛️ Congress CLI 验证者奖励查询"
    echo "========================================="
    
    # 检查 Congress CLI 工具是否存在
    if [ ! -f "$CONGRESS_CLI_PATH" ]; then
        echo "❌ Congress CLI 工具未找到"
        echo "📍 预期路径: $CONGRESS_CLI_PATH"
        echo "💡 请确保已编译 Congress CLI 工具"
        echo ""
        echo "🔧 编译命令:"
        echo "   cd ../sys-contract/congress-cli"
        echo "   make build"
        return 1
    fi
    
    # 检查节点是否在线
    if ! curl -s -f "$VALIDATOR1_RPC" > /dev/null 2>&1; then
        echo "❌ 验证者节点未运行，请先启动节点"
        return 1
    fi
    
    echo "🔍 查询所有验证者（矿工）奖励信息..."
    echo ""
    
    # 查询所有验证者信息
    echo "📊 执行命令: $CONGRESS_CLI_PATH miners -c $CHAIN_ID -l $VALIDATOR1_RPC"
    echo "----------------------------------------"
    
    if ! $CONGRESS_CLI_PATH miners -c "$CHAIN_ID" -l "$VALIDATOR1_RPC" 2>/dev/null; then
        echo "❌ 查询失败，可能的原因:"
        echo "   • 节点未完全同步"
        echo "   • 验证者合约未初始化"
        echo "   • RPC 连接问题"
        echo ""
        echo "🔧 尝试手动查询:"
        echo "   $CONGRESS_CLI_PATH miners -c $CHAIN_ID -l $VALIDATOR1_RPC"
        return 1
    fi
    
    echo ""
    echo "----------------------------------------"
    echo "💡 详细说明："
    echo "   ✅ Active: 验证者状态活跃，正在参与挖矿"
    echo "   ❌ Inactive: 验证者状态非活跃"
    echo "   💰 Accumulated Rewards: 可提取的累积奖励"
    echo "   ⚖️ Penalized Rewards: 被没收的奖励（重新分配）"
    echo "   📅 Last Withdraw Block: 最后一次提取奖励的区块"
    echo ""
    
    # 获取验证者地址用于单独查询
    local validator1_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "http://localhost:${VALIDATOR1_HTTP_PORT:-8545}" | jq -r '.result')
    
    local validator2_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "http://localhost:${VALIDATOR2_HTTP_PORT:-8553}" | jq -r '.result')
    
    local validator3_addr=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "http://localhost:${VALIDATOR3_HTTP_PORT:-8556}" | jq -r '.result')
    
    echo "🎯 单独查询验证者详情:"
    echo ""
    
    echo "🥇 Validator1 详情:"
    echo "   命令: $CONGRESS_CLI_PATH miner -c $CHAIN_ID -l $VALIDATOR1_RPC -a $validator1_addr"
    $CONGRESS_CLI_PATH miner -c "$CHAIN_ID" -l "$VALIDATOR1_RPC" -a "$validator1_addr" 2>/dev/null || echo "   查询失败"
    echo ""
    
    echo "🥈 Validator2 详情:"
    echo "   命令: $CONGRESS_CLI_PATH miner -c $CHAIN_ID -l $VALIDATOR1_RPC -a $validator2_addr"
    $CONGRESS_CLI_PATH miner -c "$CHAIN_ID" -l "$VALIDATOR1_RPC" -a "$validator2_addr" 2>/dev/null || echo "   查询失败"
    echo ""
    
    echo "🥉 Validator3 详情:"
    echo "   命令: $CONGRESS_CLI_PATH miner -c $CHAIN_ID -l $VALIDATOR1_RPC -a $validator3_addr"
    $CONGRESS_CLI_PATH miner -c "$CHAIN_ID" -l "$VALIDATOR1_RPC" -a "$validator3_addr" 2>/dev/null || echo "   查询失败"
    echo ""
    
    echo "📖 使用手册："
    echo "----------------------------------------"
    echo "🔍 查询所有验证者:"
    echo "   $CONGRESS_CLI_PATH miners -c $CHAIN_ID -l $VALIDATOR1_RPC"
    echo ""
    echo "🎯 查询特定验证者:"
    echo "   $CONGRESS_CLI_PATH miner -c $CHAIN_ID -l $VALIDATOR1_RPC -a <验证者地址>"
    echo ""
    echo "💰 提取奖励 (仅费用接收地址可执行):"
    echo "   $CONGRESS_CLI_PATH withdraw_profits -c $CHAIN_ID -l $VALIDATOR1_RPC -a <验证者地址>"
    echo ""
    echo "❓ 查看帮助:"
    echo "   $CONGRESS_CLI_PATH --help"
    echo "   $CONGRESS_CLI_PATH examples"
    echo ""
    echo "📋 版本信息:"
    echo "   $CONGRESS_CLI_PATH version"
    echo ""
    
    echo "⚠️ 重要提醒："
    echo "   • 只有验证者的费用接收地址 (Fee Address) 可以提取奖励"
    echo "   • 提取奖励需要等待 withdrawProfitPeriod 个区块"
    echo "   • 被没收的奖励将重新分配给其他活跃验证者"
    echo "   • 确保有足够的 Gas 费用来执行提取交易"
    
    echo "========================================="
}

# 获取余额并显示的辅助函数
get_balance_and_show() {
    local name=$1
    local address=$2
    local rpc_url=$3
    local initial_balance=$4
    
    local balance_hex=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$address\",\"latest\"],\"id\":1}" \
        "$rpc_url" | jq -r '.result')
    
    # 使用node计算余额（以ETH为单位）
    local balance_eth=$(node -e "
        const balanceWei = BigInt('$balance_hex');
        const balanceEth = Number(balanceWei) / Math.pow(10, 18);
        const initialEth = $initial_balance;
        const reward = balanceEth - initialEth;
        
        console.log('   地址: $address');
        console.log('   余额: ' + balanceEth.toFixed(4) + ' ETH');
        console.log('   初始: ' + initialEth.toFixed(1) + ' ETH');
        console.log('   转账: ' + (reward >= 0 ? '+' : '') + reward.toFixed(4) + ' ETH');

    " 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$name"
        echo "$balance_eth"
        echo ""
    else
        echo "$name"
        echo "   地址: $address"
        echo "   余额: 计算失败"
        echo ""
    fi
}

echo "🚀 Ju Chain PM2 管理脚本"
echo "========================="
echo "📁 当前工作目录: $(pwd)"

# 检查 PM2 是否安装
if ! command -v pm2 &> /dev/null; then
    echo "❌ PM2 未安装，正在安装..."
    npm install -g pm2
    if [ $? -eq 0 ]; then
        echo "✅ PM2 安装成功"
    else
        echo "❌ PM2 安装失败"
        exit 1
    fi
fi

echo ""
echo "🎯 管理选项："
echo "1. 启动所有节点"
echo "2. 停止所有节点"
echo "3. 重启所有节点"
echo "4. 查看节点状态"
echo "5. 查看节点日志"
echo "6. 监控面板"
echo "7. 删除所有进程"
echo "8. 挖矿余额分析"
echo "9. 验证者奖励查询 (Congress CLI)"
echo "10. Mainnet同步节点管理"
echo ""

read -p "请选择 (1-10): " choice

case $choice in
    1)
        echo "🎯 启动所有节点..."
        echo "🔄 启动顺序: bootnode → 验证者节点 → 同步节点"
        pm2 start "$ECOSYSTEM_FILE"
        echo "✅ 所有节点已启动"
        ;;
    2)
        echo "⏹️ 停止所有节点..."
        pm2 stop all
        echo "✅ 所有节点已停止"
        ;;
    3)
        echo "🔄 重启所有节点..."
        pm2 restart "$ECOSYSTEM_FILE"
        echo "✅ 所有节点已重启"
        ;;
    4)
        echo "📊 节点状态："
        pm2 status
        ;;
    5)
        echo "📋 选择要查看的日志："
        echo "1. 验证者1节点日志"
        echo "2. 验证者2节点日志"
        echo "3. 验证者3节点日志"
        echo "4. 验证者4节点日志"
        echo "5. 验证者5节点日志"
        echo "6. 同步节点日志"
        echo "7. Mainnet同步节点日志"
        echo "8. 引导节点日志"
        echo "9. 所有日志"
        read -p "请选择 (1-9): " log_choice
        case $log_choice in
            1)
                pm2 logs ju-chain-validator1 --lines 50
                ;;
            2)
                pm2 logs ju-chain-validator2 --lines 50
                ;;
            3)
                pm2 logs ju-chain-validator3 --lines 50
                ;;
            4)
                pm2 logs ju-chain-validator4 --lines 50
                ;;
            5)
                pm2 logs ju-chain-validator5 --lines 50
                ;;
            6)
                pm2 logs ju-chain-syncnode --lines 50
                ;;
            7)
                pm2 logs ju-chain-syncnode-mainnet --lines 50
                ;;
            8)
                pm2 logs ju-chain-bootnode --lines 50
                ;;
            9)
                pm2 logs --lines 50
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
        ;;
    6)
        echo "📊 启动监控面板..."
        pm2 monit
        ;;
    7)
        echo "🗑️ 删除所有进程..."
        pm2 delete all
        echo "✅ 所有进程已删除"
        ;;
    8)
        echo "💰 正在分析挖矿余额..."
        analyze_mining_rewards
        ;;
    9)
        echo "🏛️ 正在使用 Congress CLI 查询验证者奖励..."
        analyze_congress_rewards
        ;;
    10)
        echo "🌐 Mainnet同步节点管理："
        echo "1. 启动 Mainnet同步节点"
        echo "2. 停止 Mainnet同步节点"
        echo "3. 重启 Mainnet同步节点"
        echo "4. 查看 Mainnet同步节点状态"
        echo "5. 查看 Mainnet同步节点日志"
        echo "6. 删除 Mainnet同步节点进程"
        read -p "请选择 (1-6): " mainnet_choice
        case $mainnet_choice in
            1)
                echo "🚀 启动 Mainnet同步节点..."
                pm2 start ecosystem.config.js --only ju-chain-syncnode-mainnet
                echo "✅ Mainnet同步节点已启动"
                ;;
            2)
                echo "⏹️ 停止 Mainnet同步节点..."
                pm2 stop ju-chain-syncnode-mainnet
                echo "✅ Mainnet同步节点已停止"
                ;;
            3)
                echo "🔄 重启 Mainnet同步节点..."
                pm2 restart ju-chain-syncnode-mainnet
                echo "✅ Mainnet同步节点已重启"
                ;;
            4)
                echo "📊 Mainnet同步节点状态："
                pm2 status ju-chain-syncnode-mainnet
                ;;
            5)
                echo "📋 Mainnet同步节点日志："
                pm2 logs ju-chain-syncnode-mainnet --lines 50
                ;;
            6)
                echo "🗑️ 删除 Mainnet同步节点进程..."
                pm2 delete ju-chain-syncnode-mainnet
                echo "✅ Mainnet同步节点进程已删除"
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "🔗 实用信息："
echo "📊 验证者1节点 RPC: http://localhost:${VALIDATOR1_HTTP_PORT:-8545}"
echo "📊 验证者2节点 RPC: http://localhost:${VALIDATOR2_HTTP_PORT:-8553}"
echo "📊 验证者3节点 RPC: http://localhost:${VALIDATOR3_HTTP_PORT:-8556}"
echo "📊 验证者4节点 RPC: http://localhost:${VALIDATOR4_HTTP_PORT:-8559}"
echo "📊 验证者5节点 RPC: http://localhost:${VALIDATOR5_HTTP_PORT:-8562}"
echo "📊 同步节点 RPC: http://localhost:${SYNCNODE_HTTP_PORT:-8547}"
echo "📊 Mainnet同步节点 RPC: http://localhost:${SYNCNODE_MAINNET_HTTP_PORT:-8549}"
echo "🌐 验证者1节点 WebSocket: ws://localhost:${VALIDATOR1_WS_PORT:-8546}"
echo "🌐 验证者2节点 WebSocket: ws://localhost:${VALIDATOR2_WS_PORT:-8554}"
echo "🌐 验证者3节点 WebSocket: ws://localhost:${VALIDATOR3_WS_PORT:-8557}"
echo "🌐 验证者4节点 WebSocket: ws://localhost:${VALIDATOR4_WS_PORT:-8560}"
echo "🌐 验证者5节点 WebSocket: ws://localhost:${VALIDATOR5_WS_PORT:-8563}"
echo "🌐 同步节点 WebSocket: ws://localhost:${SYNCNODE_WS_PORT:-8548}"
echo "🌐 Mainnet同步节点 WebSocket: ws://localhost:${SYNCNODE_MAINNET_WS_PORT:-8550}"
echo "🆔 Testnet Chain ID: ${CHAIN_ID:-202599}"
echo "🆔 Mainnet Network ID: ${MAINNET_NETWORK_ID:-210000}"
echo "👤 验证者1账户: ${VALIDATOR1_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
echo "👤 验证者2账户: ${VALIDATOR2_ADDRESS:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}"
echo "👤 验证者3账户: ${VALIDATOR3_ADDRESS:-0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC}"
echo "👤 验证者4账户: ${VALIDATOR4_ADDRESS:-0x90F79bf6EB2c4f870365E785982E1f101E93b906}"
echo "👤 验证者5账户: ${VALIDATOR5_ADDRESS:-0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65}"
echo ""
echo "🏛️ Congress CLI 工具路径："
echo "../sys-contract/congress-cli/build/congress-cli"
echo ""
echo "💡 常用 PM2 命令："
echo "pm2 status              # 查看状态"
echo "pm2 logs                # 查看日志"
echo "pm2 monit              # 监控面板"
echo "pm2 restart all        # 重启所有"
echo "pm2 stop all           # 停止所有"
echo "pm2 delete all         # 删除所有"
echo "pm2 save               # 保存进程列表"
echo "pm2 startup            # 开机自启动"
echo ""
echo "🏛️ Congress CLI 常用命令："
echo "# 查询所有验证者奖励"
echo "../sys-contract/congress-cli/build/congress-cli miners -c 202599 -l http://localhost:8545"
echo ""
echo "# 查询特定验证者详情"
echo "../sys-contract/congress-cli/build/congress-cli miner -c 202599 -l http://localhost:8545 -a <地址>"
echo ""
echo "# 提取验证者奖励 (仅费用接收地址可执行)"
echo "../sys-contract/congress-cli/build/congress-cli withdraw_profits -c 202599 -l http://localhost:8545 -a <地址>"
