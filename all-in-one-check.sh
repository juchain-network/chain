#!/bin/bash

# Ju Chain All-in-One Check Script
# 统一监控和检查脚本 - 包含所有功能
# 创建时间: 202599-08-20

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
VALIDATOR_COUNT=5
SYNCNODE_COUNT=2
NETWORK_ID="202599"
MAINNET_ID="210000"

# 端口配置
VALIDATOR_PORTS=(8545 8553 8556 8559 8562)
SYNCNODE_PORTS=(8547 8549)
P2P_PORTS=(30301 30303 30304 30305 30306 30302 30312)

# 输出格式化函数
print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "============================================================"
}

print_subheader() {
    echo -e "\n${CYAN}$1${NC}"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${PURPLE}📋 $1${NC}"
}

# 帮助信息
show_help() {
    cat << EOF
Ju Chain All-in-One Check Script

用法: $0 [选项]

选项:
    -h, --help          显示此帮助信息
    -q, --quick         快速检查模式
    -f, --full          完整检查模式 (默认)
    -m, --mining        仅检查挖矿状态
    -p, --processes     仅检查PM2进程
    -n, --network       仅检查网络连接
    -s, --system        仅检查系统资源
    -v, --validator ID  检查特定验证者 (1-5)
    --json              输出JSON格式结果
    --no-color          禁用颜色输出

示例:
    $0                  # 完整检查
    $0 -q               # 快速检查
    $0 -v 2             # 检查验证者2
    $0 --mining         # 仅检查挖矿状态
    $0 --json           # JSON格式输出
EOF
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq" "lsof" "pm2")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "缺少依赖: ${missing[*]}"
        echo "请安装缺少的依赖后重试"
        exit 1
    fi
}

# PM2进程检查
check_pm2_processes() {
    print_subheader "📋 PM2进程状态检查"
    
    local processes=("ju-chain-validator1" "ju-chain-validator2" "ju-chain-validator3" 
                    "ju-chain-validator4" "ju-chain-validator5" "ju-chain-syncnode" 
                    "ju-chain-syncnode-mainnet")
    
    local online_count=0
    local total_count=${#processes[@]}
    
    for process in "${processes[@]}"; do
        if pm2 describe "$process" &>/dev/null; then
            local status=$(pm2 describe "$process" | grep -o 'status.*online\|status.*stopped' | head -1)
            if [[ $status == *"online"* ]]; then
                print_success "$process"
                ((online_count++))
            else
                print_error "$process - 进程停止"
            fi
        else
            print_error "$process - 进程不存在"
        fi
    done
    
    echo
    if [ $online_count -eq $total_count ]; then
        print_success "所有 $total_count 个进程在线"
    else
        print_warning "$online_count/$total_count 个进程在线"
    fi
    
    return $((total_count - online_count))
}

# 检查节点HTTP接口
check_node_http() {
    local port=$1
    local name=$2
    local timeout=3
    
    local response=$(curl -s --max-time $timeout \
        -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
        "http://localhost:$port" 2>/dev/null)
    
    if [[ $response == *"$NETWORK_ID"* ]] || [[ $response == *"$MAINNET_ID"* ]]; then
        return 0
    else
        return 1
    fi
}

# 获取区块信息
get_block_info() {
    local port=$1
    local timeout=3
    
    local response=$(curl -s --max-time $timeout \
        -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "http://localhost:$port" 2>/dev/null)
    
    if [[ $response == *"result"* ]]; then
        local hex_block=$(echo "$response" | jq -r '.result' 2>/dev/null)
        if [[ $hex_block != "null" ]] && [[ $hex_block != "" ]]; then
            printf "%d" "$hex_block" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# 检查挖矿状态
check_mining_status() {
    local port=$1
    local timeout=3
    
    local response=$(curl -s --max-time $timeout \
        -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' \
        "http://localhost:$port" 2>/dev/null)
    
    if [[ $response == *"true"* ]]; then
        return 0
    else
        return 1
    fi
}

# 检查P2P连接数
get_peer_count() {
    local port=$1
    local timeout=3
    
    local response=$(curl -s --max-time $timeout \
        -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        "http://localhost:$port" 2>/dev/null)
    
    if [[ $response == *"result"* ]]; then
        local hex_peers=$(echo "$response" | jq -r '.result' 2>/dev/null)
        if [[ $hex_peers != "null" ]] && [[ $hex_peers != "" ]]; then
            printf "%d" "$hex_peers" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# 检查交易池状态
check_transaction_pool() {
    local port=$1
    local node_name=$2
    local timeout=3
    
    local result=$(curl -s --max-time $timeout \
        -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}' \
        "http://localhost:$port" 2>/dev/null)
    
    if [[ $result == *"result"* ]]; then
        local pending=$(echo "$result" | jq -r '.result.pending // "0x0"' 2>/dev/null | xargs printf "%d" 2>/dev/null || echo "0")
        local queued=$(echo "$result" | jq -r '.result.queued // "0x0"' 2>/dev/null | xargs printf "%d" 2>/dev/null || echo "0")
        echo "$pending:$queued"
    else
        echo "0:0"
    fi
}

# 节点状态检查
check_node_status() {
    print_subheader "🔍 节点状态检查"
    
    local online_nodes=0
    local total_nodes=$((VALIDATOR_COUNT + SYNCNODE_COUNT))
    
    # 检查验证者节点
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local port=${VALIDATOR_PORTS[$((i-1))]}
        local node_name="验证者$i"
        
        if check_node_http $port "$node_name"; then
            print_success "$node_name (端口:$port) - 在线"
            # 检查交易池状态
            local txpool=$(check_transaction_pool $port "$node_name")
            local pending=$(echo "$txpool" | cut -d: -f1)
            local queued=$(echo "$txpool" | cut -d: -f2)
            if [ "$pending" -gt 0 ] || [ "$queued" -gt 0 ]; then
                print_info "  交易池: 待处理=${pending}, 排队=${queued}"
            else
                print_success "  交易池: 空闲"
            fi
            ((online_nodes++))
        else
            print_error "$node_name (端口:$port) - 离线"
        fi
    done
    
    # 检查同步节点
    local sync_names=("测试网同步节点" "主网同步节点")
    for i in $(seq 0 $((SYNCNODE_COUNT-1))); do
        local port=${SYNCNODE_PORTS[$i]}
        local node_name=${sync_names[$i]}
        
        if check_node_http $port "$node_name"; then
            print_success "$node_name (端口:$port) - 在线"
            # 检查交易池状态
            local txpool=$(check_transaction_pool $port "$node_name")
            local pending=$(echo "$txpool" | cut -d: -f1)
            local queued=$(echo "$txpool" | cut -d: -f2)
            if [ "$pending" -gt 0 ] || [ "$queued" -gt 0 ]; then
                print_info "  交易池: 待处理=${pending}, 排队=${queued}"
            else
                print_success "  交易池: 空闲"
            fi
            ((online_nodes++))
        else
            print_error "$node_name (端口:$port) - 离线"
        fi
    done
    
    echo
    print_info "节点状态汇总: $online_nodes/$total_nodes 节点在线"
    
    return $((total_nodes - online_nodes))
}

# 网络同步检查
check_sync_status() {
    print_subheader "🔄 网络同步状态检查"
    
    local max_block=0
    local blocks=()
    
    # 获取所有验证者的区块高度
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local port=${VALIDATOR_PORTS[$((i-1))]}
        local block=$(get_block_info $port)
        blocks+=($block)
        
        if [ $block -gt $max_block ]; then
            max_block=$block
        fi
    done
    
    print_info "网络最高区块: #$max_block"
    
    # 检查每个验证者的同步状态
    local synced_count=0
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local block=${blocks[$((i-1))]}
        local diff=$((max_block - block))
        
        if [ $diff -le 1 ]; then
            print_success "验证者$i: #$block (差异: $diff 块)"
            ((synced_count++))
        else
            print_warning "验证者$i: #$block (差异: $diff 块)"
        fi
    done
    
    echo
    if [ $synced_count -eq $VALIDATOR_COUNT ]; then
        print_success "所有验证者完全同步"
    else
        print_warning "$synced_count/$VALIDATOR_COUNT 验证者完全同步"
    fi
    
    return $((VALIDATOR_COUNT - synced_count))
}

# 挖矿状态检查
check_mining() {
    print_subheader "⛏️  验证者挖矿状态检查"
    
    local mining_count=0
    
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local port=${VALIDATOR_PORTS[$((i-1))]}
        
        if check_mining_status $port; then
            print_success "验证者$i: 正在挖矿"
            ((mining_count++))
        else
            print_error "验证者$i: 未在挖矿"
        fi
    done
    
    echo
    print_info "挖矿状态汇总: $mining_count/$VALIDATOR_COUNT 验证者正在挖矿"
    
    return $((VALIDATOR_COUNT - mining_count))
}

# P2P网络检查
check_p2p_network() {
    print_subheader "🌐 P2P网络连接检查"
    
    local total_peers=0
    local connected_nodes=0
    
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local port=${VALIDATOR_PORTS[$((i-1))]}
        local peers=$(get_peer_count $port)
        
        if [ $peers -gt 0 ]; then
            print_success "验证者$i: $peers 个连接"
            total_peers=$((total_peers + peers))
            ((connected_nodes++))
        else
            print_warning "验证者$i: $peers 个连接"
        fi
    done
    
    echo
    if [ $connected_nodes -gt 0 ]; then
        local avg_peers=$((total_peers / connected_nodes))
        print_info "平均P2P连接数: $avg_peers"
    else
        print_error "没有P2P连接"
    fi
    
    return $((VALIDATOR_COUNT - connected_nodes))
}

# 最近区块检查
check_recent_blocks() {
    print_subheader "📦 最近区块生产情况"
    
    local port=${VALIDATOR_PORTS[0]}
    local current_block=$(get_block_info $port)
    
    if [ $current_block -eq 0 ]; then
        print_error "无法获取区块信息"
        return 1
    fi
    
    local block_count=10
    local start_block=$((current_block - block_count + 1))
    
    print_info "检查最近 $block_count 个区块 (#$start_block - #$current_block):"
    
    for i in $(seq $start_block $current_block); do
        local response=$(curl -s --max-time 3 \
            -X POST -H "Content-Type: application/json" \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"0x$(printf '%x' $i)\",false],\"id\":1}" \
            "http://localhost:$port" 2>/dev/null)
        
        if [[ $response == *"result"* ]]; then
            local miner=$(echo "$response" | jq -r '.result.miner' 2>/dev/null)
            local timestamp=$(echo "$response" | jq -r '.result.timestamp' 2>/dev/null)
            
            if [[ $miner != "null" ]] && [[ $miner != "" ]]; then
                local short_miner="${miner:0:10}...${miner: -6}"
                echo "📦 区块 #$i: $short_miner"
            else
                echo "📦 区块 #$i: 未知矿工"
            fi
        else
            echo "📦 区块 #$i: 获取失败"
        fi
    done
}

# 系统资源检查
check_system_resources() {
    print_subheader "💾 系统资源检查"
    
    # 磁盘空间检查
    local disk_info=$(df -h . | tail -1)
    local disk_usage=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    local disk_avail=$(echo "$disk_info" | awk '{print $4}')
    local disk_size=$(echo "$disk_info" | awk '{print $2}')
    
    # 计算剩余空间百分比（去掉单位后的数值比较）
    local avail_num=$(echo "$disk_avail" | sed 's/Gi\|Mi\|Ti\|Ki\|G\|M\|T\|K//')
    local size_num=$(echo "$disk_size" | sed 's/Gi\|Mi\|Ti\|Ki\|G\|M\|T\|K//')
    
    if [ $disk_usage -lt 30 ]; then
        print_success "磁盘空间: 已用${disk_usage}%, 剩余${disk_avail}/${disk_size} (充足)"
    elif [ $disk_usage -lt 60 ]; then
        print_warning "磁盘空间: 已用${disk_usage}%, 剩余${disk_avail}/${disk_size} (适中)"
    else
        print_error "磁盘空间: 已用${disk_usage}%, 剩余${disk_avail}/${disk_size} (空间不足)"
    fi
    
    # 内存使用检查
    if command -v pm2 &> /dev/null; then
        print_info "PM2进程内存使用情况:"
        pm2 status | grep "ju-chain" | while read line; do
            echo "  $line"
        done
    fi
    
    # 端口占用检查
    print_info "关键端口占用情况:"
    for port in "${VALIDATOR_PORTS[@]}" "${SYNCNODE_PORTS[@]}"; do
        if lsof -i ":$port" &>/dev/null; then
            local process=$(lsof -i ":$port" | awk 'NR==2 {print $1}')
            print_success "端口 $port: $process"
        else
            print_warning "端口 $port: 未占用"
        fi
    done
}

# 网络健康评分
calculate_health_score() {
    local pm2_score=$1
    local node_score=$2
    local sync_score=$3
    local mining_score=$4
    local p2p_score=$5
    
    local total_checks=5
    local passed_checks=0
    
    [ $pm2_score -eq 0 ] && ((passed_checks++))
    [ $node_score -eq 0 ] && ((passed_checks++))
    [ $sync_score -eq 0 ] && ((passed_checks++))
    [ $mining_score -eq 0 ] && ((passed_checks++))
    [ $p2p_score -eq 0 ] && ((passed_checks++))
    
    echo $((passed_checks * 100 / total_checks))
}

# 生成健康报告
generate_health_report() {
    local pm2_result=$1
    local node_result=$2
    local sync_result=$3
    local mining_result=$4
    local p2p_result=$5
    
    print_header "🏥 网络健康评分报告"
    
    local health_score=$(calculate_health_score $pm2_result $node_result $sync_result $mining_result $p2p_result)
    
    echo "评分项目:"
    [ $pm2_result -eq 0 ] && print_success "PM2进程: 正常" || print_error "PM2进程: 异常"
    [ $node_result -eq 0 ] && print_success "节点在线: 正常" || print_error "节点在线: 异常"
    [ $sync_result -eq 0 ] && print_success "区块同步: 正常" || print_error "区块同步: 异常"
    [ $mining_result -eq 0 ] && print_success "挖矿状态: 正常" || print_error "挖矿状态: 异常"
    [ $p2p_result -eq 0 ] && print_success "P2P连接: 正常" || print_error "P2P连接: 异常"
    
    echo
    print_info "总体健康评分: $health_score/100"
    
    if [ $health_score -ge 90 ]; then
        print_success "网络状态极佳! 🎉"
    elif [ $health_score -ge 70 ]; then
        print_success "网络状态良好 ✅"
    elif [ $health_score -ge 50 ]; then
        print_warning "网络状态一般 ⚠️"
    else
        print_error "网络状态异常 ❌"
    fi
}

# 检查特定验证者
check_specific_validator() {
    local validator_id=$1
    
    if [ $validator_id -lt 1 ] || [ $validator_id -gt $VALIDATOR_COUNT ]; then
        print_error "验证者ID必须在1-$VALIDATOR_COUNT之间"
        return 1
    fi
    
    print_header "🔍 验证者$validator_id 详细状态检查"
    
    local port=${VALIDATOR_PORTS[$((validator_id-1))]}
    
    # 基本连接检查
    if check_node_http $port "验证者$validator_id"; then
        print_success "HTTP接口: 正常 (端口: $port)"
    else
        print_error "HTTP接口: 异常 (端口: $port)"
        return 1
    fi
    
    # 挖矿状态
    if check_mining_status $port; then
        print_success "挖矿状态: 正在挖矿"
    else
        print_error "挖矿状态: 未在挖矿"
    fi
    
    # 区块高度
    local block=$(get_block_info $port)
    print_info "当前区块: #$block"
    
    # P2P连接
    local peers=$(get_peer_count $port)
    if [ $peers -gt 0 ]; then
        print_success "P2P连接: $peers 个节点"
    else
        print_warning "P2P连接: $peers 个节点"
    fi
    
    # 交易池状态
    local txpool=$(check_transaction_pool $port "验证者$validator_id")
    local pending=$(echo "$txpool" | cut -d: -f1)
    local queued=$(echo "$txpool" | cut -d: -f2)
    if [ "$pending" -gt 0 ] || [ "$queued" -gt 0 ]; then
        print_info "交易池状态: 待处理=${pending}, 排队=${queued}"
    else
        print_success "交易池状态: 空闲"
    fi
    
    # 获取更多详细信息
    local response=$(curl -s --max-time 3 \
        -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_coinbase","params":[],"id":1}' \
        "http://localhost:$port" 2>/dev/null)
    
    if [[ $response == *"result"* ]]; then
        local coinbase=$(echo "$response" | jq -r '.result' 2>/dev/null)
        if [[ $coinbase != "null" ]] && [[ $coinbase != "" ]]; then
            print_info "Coinbase地址: $coinbase"
        fi
    fi
    
    echo
    print_info "验证者$validator_id 状态检查完成"
}

# 快速检查模式
quick_check() {
    print_header "🚀 Ju Chain 快速状态检查"
    
    # PM2进程检查
    check_pm2_processes
    local pm2_result=$?
    
    # 挖矿状态检查
    print_subheader "⛏️  验证者挖矿状态"
    local mining_count=0
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local port=${VALIDATOR_PORTS[$((i-1))]}
        if check_mining_status $port; then
            print_success "验证者$i - 挖矿中"
            ((mining_count++))
        else
            print_error "验证者$i - 未挖矿"
        fi
    done
    
    # 最新区块信息
    print_subheader "📦 最新区块信息"
    local port=${VALIDATOR_PORTS[0]}
    local current_block=$(get_block_info $port)
    
    if [ $current_block -gt 0 ]; then
        print_success "区块高度: #$current_block"
        
        # 获取最新区块的矿工信息
        local response=$(curl -s --max-time 3 \
            -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
            "http://localhost:$port" 2>/dev/null)
        
        if [[ $response == *"result"* ]]; then
            local miner=$(echo "$response" | jq -r '.result.miner' 2>/dev/null)
            local timestamp=$(echo "$response" | jq -r '.result.timestamp' 2>/dev/null)
            
            if [[ $miner != "null" ]] && [[ $miner != "" ]]; then
                print_info "出块者: $miner"
                
                if [[ $timestamp != "null" ]] && [[ $timestamp != "" ]]; then
                    # 移除0x前缀并转换时间戳
                    local clean_timestamp=${timestamp#0x}
                    # 确保时间戳是有效的十六进制数
                    if [[ $clean_timestamp =~ ^[0-9a-fA-F]+$ ]]; then
                        local block_timestamp_dec=$((16#$clean_timestamp))
                        # macOS使用 -r 参数，Linux使用 -d 参数
                        local block_time
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            block_time=$(date -r "$block_timestamp_dec" '+%H:%M:%S' 2>/dev/null || echo "未知")
                        else
                            block_time=$(date -d "@$block_timestamp_dec" '+%H:%M:%S' 2>/dev/null || echo "未知")
                        fi
                        print_info "出块时间: $block_time"
                        
                        local current_time=$(date +%s)
                        local time_diff=$((current_time - block_timestamp_dec))
                    else
                        print_info "出块时间: 时间戳格式错误 ($timestamp)"
                        local time_diff=999
                    fi
                else
                    print_info "出块时间: 无时间戳数据"
                    local time_diff=999
                fi
                    
                if [ $time_diff -lt 10 ]; then
                    print_success "网络活跃 (最新区块 ${time_diff}秒前)"
                else
                    print_warning "网络可能滞后 (最新区块 ${time_diff}秒前)"
                fi
            fi
        fi
    else
        print_error "无法获取区块信息"
    fi
    
    # 快速汇总
    print_subheader "📊 快速汇总"
    print_info "活跃验证者: $mining_count/$VALIDATOR_COUNT"
    
    if [ $pm2_result -eq 0 ] && [ $mining_count -eq $VALIDATOR_COUNT ]; then
        print_success "网络运行正常"
    else
        print_warning "网络存在问题，建议运行完整检查"
    fi
}

# 完整检查模式
full_check() {
    print_header "🏥 Ju Chain 网络完整健康检查"
    
    # 依赖检查
    check_dependencies
    
    # 各项检查
    check_pm2_processes
    local pm2_result=$?
    
    check_node_status
    local node_result=$?
    
    check_sync_status
    local sync_result=$?
    
    check_mining
    local mining_result=$?
    
    check_p2p_network
    local p2p_result=$?
    
    check_recent_blocks
    
    check_system_resources
    
    # 生成健康报告
    generate_health_report $pm2_result $node_result $sync_result $mining_result $p2p_result
}

# JSON输出模式
json_output() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local pm2_status=()
    local node_status=()
    local mining_status=()
    local p2p_status=()
    
    # 收集PM2状态
    local processes=("ju-chain-validator1" "ju-chain-validator2" "ju-chain-validator3" 
                    "ju-chain-validator4" "ju-chain-validator5" "ju-chain-syncnode" 
                    "ju-chain-syncnode-mainnet")
    
    for process in "${processes[@]}"; do
        if pm2 describe "$process" &>/dev/null; then
            local status=$(pm2 describe "$process" | grep -o 'status.*online\|status.*stopped' | head -1)
            if [[ $status == *"online"* ]]; then
                pm2_status+=("\"$process\":\"online\"")
            else
                pm2_status+=("\"$process\":\"offline\"")
            fi
        else
            pm2_status+=("\"$process\":\"not_found\"")
        fi
    done
    
    # 收集节点状态
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local port=${VALIDATOR_PORTS[$((i-1))]}
        local block=$(get_block_info $port)
        local peers=$(get_peer_count $port)
        local mining=$(check_mining_status $port && echo "true" || echo "false")
        local online=$(check_node_http $port "validator$i" && echo "true" || echo "false")
        
        node_status+=("\"validator$i\":{\"port\":$port,\"online\":$online,\"block\":$block,\"peers\":$peers,\"mining\":$mining}")
    done
    
    # 输出JSON
    cat << EOF
{
  "timestamp": "$timestamp",
  "network_id": "$NETWORK_ID",
  "pm2_processes": {
    $(IFS=','; echo "${pm2_status[*]}")
  },
  "validators": {
    $(IFS=','; echo "${node_status[*]}")
  },
  "summary": {
    "total_validators": $VALIDATOR_COUNT,
    "validator_ports": [$(IFS=','; echo "${VALIDATOR_PORTS[*]}")],
    "syncnode_ports": [$(IFS=','; echo "${SYNCNODE_PORTS[*]}")]
  }
}
EOF
}

# 主函数
main() {
    local mode="full"
    local validator_id=""
    local use_json=false
    local no_color=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -q|--quick)
                mode="quick"
                shift
                ;;
            -f|--full)
                mode="full"
                shift
                ;;
            -m|--mining)
                mode="mining"
                shift
                ;;
            -p|--processes)
                mode="processes"
                shift
                ;;
            -n|--network)
                mode="network"
                shift
                ;;
            -s|--system)
                mode="system"
                shift
                ;;
            -v|--validator)
                mode="validator"
                validator_id="$2"
                shift 2
                ;;
            --json)
                use_json=true
                shift
                ;;
            --no-color)
                no_color=true
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                PURPLE=''
                CYAN=''
                NC=''
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # JSON模式
    if [ "$use_json" = true ]; then
        json_output
        exit 0
    fi
    
    # 根据模式执行相应检查
    case $mode in
        quick)
            quick_check
            ;;
        full)
            full_check
            ;;
        mining)
            print_header "⛏️  挖矿状态检查"
            check_mining
            ;;
        processes)
            print_header "📋 PM2进程检查"
            check_pm2_processes
            ;;
        network)
            print_header "🌐 网络连接检查"
            check_p2p_network
            ;;
        system)
            print_header "💾 系统资源检查"
            check_system_resources
            ;;
        validator)
            if [[ $validator_id =~ ^[1-5]$ ]]; then
                check_specific_validator $validator_id
            else
                print_error "验证者ID必须在1-5之间"
                exit 1
            fi
            ;;
        *)
            echo "未知模式: $mode"
            show_help
            exit 1
            ;;
    esac
    
    echo
    print_info "检查完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 脚本入口
main "$@"
