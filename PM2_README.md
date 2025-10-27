# Ju Chain PM2 管理指南

## 概述

Ju Chain 是一个基于 Go-Ethereum 的私有区块链网络，使用 Congress (PoA) 共识机制。本指南介绍如何使用 PM2 管理 5 个验证者节点的区块链网络。

## 快速开始

### 1. 环境要求

- **操作系统**: Linux/macOS
- **Node.js**: v20+
- **PM2**: 全局安装
- **Go**: v1.23+ (如需重新编译)
- **内存**: 建议 8GB+
- **磁盘空间**: 建议 10GB+

```bash
# 安装 PM2
npm install -g pm2

# 验证安装
pm2 --version
node --version
```

### 2. 初始化环境

```bash
# 进入项目目录
cd /path/to/ju-chain-work/chain

# 复制配置文件模板
cp .env.example .env

# 编辑配置文件（可选，默认配置已可用）
nano .env

# 运行初始化脚本（仅需执行一次，否则会清空数据）
./pm2-init.sh
```

**⚠️ 注意**: `pm2-init.sh` 会清空现有数据，仅在首次初始化或需要重置时运行。

### 3. 启动节点

```bash
# 使用管理脚本（推荐）
./pm2-manager.sh

# 或直接使用 PM2
pm2 start ecosystem.config.js

# 查看启动状态
pm2 status
```

### 4. 验证运行状态

```bash
# 检查所有节点状态
pm2 status

# 检查区块同步
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# 使用管理脚本查看详细状态
./pm2-manager.sh
```

## 节点配置

### 验证者节点 1 (ju-chain-validator1)

- **端口**: HTTP RPC (8545), WebSocket (8546), Engine (8551), P2P (30301)
- **功能**: 参与 Congress 共识，产生区块
- **账户**: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
- **数据目录**: `./private-chain/data-validator1`

### 验证者节点 2 (ju-chain-validator2)

- **端口**: HTTP RPC (8553), WebSocket (8554), Engine (8555), P2P (30303)
- **功能**: 参与 Congress 共识，产生区块
- **账户**: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
- **数据目录**: `./private-chain/data-validator2`

### 验证者节点 3 (ju-chain-validator3)

- **端口**: HTTP RPC (8556), WebSocket (8557), Engine (8558), P2P (30304)
- **功能**: 参与 Congress 共识，产生区块
- **账户**: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
- **数据目录**: `./private-chain/data-validator3`

### 验证者节点 4 (ju-chain-validator4)

- **端口**: HTTP RPC (8559), WebSocket (8560), Engine (8561), P2P (30305)
- **功能**: 参与 Congress 共识，产生区块
- **账户**: 0x90F79bf6EB2c4f870365E785982E1f101E93b906
- **数据目录**: `./private-chain/data-validator4`

### 验证者节点 5 (ju-chain-validator5)

- **端口**: HTTP RPC (8562), WebSocket (8563), Engine (8564), P2P (30306)
- **功能**: 参与 Congress 共识，产生区块
- **账户**: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
- **数据目录**: `./private-chain/data-validator5`

### 同步节点 (ju-chain-syncnode)  

- **端口**: HTTP RPC (8547), WebSocket (8548)
- **功能**: 只同步区块，不参与共识
- **数据目录**: `./private-chain/data-sync`

### 引导节点 (ju-chain-bootnode)

- **端口**: P2P (30300)
- **功能**: 网络发现和节点连接
- **密钥文件**: `./private-chain/bootnode/boot.key`

## 网络架构

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Validator1    │    │   Validator2    │    │   Validator3    │
│   :8545/:30301  │◄──►│   :8553/:30303  │◄──►│   :8556/:30304  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
         └───────────┬───────────┘                       │
                     │                                   │
┌─────────────────┐  │  ┌─────────────────┐             │
│   Validator4    │  │  │   Validator5    │             │
│   :8559/:30305  │◄─┼─►│   :8562/:30306  │             │
└─────────────────┘  │  └─────────────────┘             │
                     │                                   │
         ┌───────────▼───────────┐                       │
         │     Bootnode          │                       │
         │      :30300           │◄──────────────────────┘
         └───────────────────────┘
                     ▲
         ┌───────────▼───────────┐
         │    Sync Node          │
         │   :8547/:30302        │
         └───────────────────────┘
```

## PM2 常用命令

```bash
# 查看状态
pm2 status

# 查看日志
pm2 logs
pm2 logs ju-chain-validator1
pm2 logs ju-chain-validator2  
pm2 logs ju-chain-validator3
pm2 logs ju-chain-validator4
pm2 logs ju-chain-validator5
pm2 logs ju-chain-syncnode

# 重启节点
pm2 restart all
pm2 restart ju-chain-validator1
pm2 restart ju-chain-validator2
pm2 restart ju-chain-validator3
pm2 restart ju-chain-validator4
pm2 restart ju-chain-validator5

# 停止节点
pm2 stop all
pm2 stop ju-chain-validator1
pm2 stop ju-chain-validator2
pm2 stop ju-chain-validator3
pm2 stop ju-chain-validator4
pm2 stop ju-chain-validator5

# 删除进程
pm2 delete all
pm2 delete ju-chain-validator1  # 删除单个进程

# 监控面板
pm2 monit

# 保存进程列表（开机自启动）
pm2 save
pm2 startup

# 实时查看日志
pm2 logs --lines 100 --raw

# 重新加载配置（无缝重启）
pm2 reload ecosystem.config.js
```

## 高级 PM2 命令

```bash
# 显示进程详细信息
pm2 show ju-chain-validator1

# 重置计数器和日志
pm2 reset ju-chain-validator1

# 重新加载进程（0秒停机）
pm2 reload ju-chain-validator1

# 优雅停机（等待当前请求完成）
pm2 stop ju-chain-validator1 --timeout 30000

# 内存监控
pm2 monit

# 设置内存限制自动重启
pm2 restart ju-chain-validator1 --max-memory-restart 2G

# 设置 watch 模式（文件变化自动重启）
pm2 restart ju-chain-validator1 --watch

# 日志轮转
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 30
```

## 目录结构

```text
ju-chain-work/chain/
├── .env                    # 环境变量配置文件（不提交到版本控制）
├── .env.example            # 环境变量配置模板
├── ecosystem.config.js      # PM2 配置文件
├── pm2-init.sh             # 初始化脚本
├── pm2-manager.sh          # 管理脚本
├── config.toml             # 节点配置
├── genesis.json            # 创世块配置
├── package.json            # Node.js 依赖
├── build/bin/              # 编译后的二进制文件
│   ├── geth
│   └── bootnode
├── private-chain/          # 私链数据
│   ├── data-validator1/   # 验证者1节点数据
│   ├── data-validator2/   # 验证者2节点数据
│   ├── data-validator3/   # 验证者3节点数据
│   ├── data-validator4/   # 验证者4节点数据
│   ├── data-validator5/   # 验证者5节点数据
│   ├── data-sync/         # 同步节点数据
│   ├── data-sync-mainnet/ # 主网同步数据
│   └── bootnode/          # 引导节点数据
└── logs/                  # PM2 日志文件
    ├── validator1-*.log
    ├── validator2-*.log
    ├── validator3-*.log
    ├── validator4-*.log
    ├── validator5-*.log
    ├── syncnode-*.log
    └── bootnode-*.log
```

## 环境变量配置

`.env` 文件包含所有可配置的参数：

```bash
# 验证者1账户配置
VALIDATOR1_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
VALIDATOR1_PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
VALIDATOR1_PASSWORD=123456

# 验证者2账户配置  
VALIDATOR2_ADDRESS=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
VALIDATOR2_PRIVATE_KEY=59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
VALIDATOR2_PASSWORD=123456

# 验证者3账户配置
VALIDATOR3_ADDRESS=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
VALIDATOR3_PRIVATE_KEY=5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
VALIDATOR3_PASSWORD=123456

# 验证者4账户配置
VALIDATOR4_ADDRESS=0x90F79bf6EB2c4f870365E785982E1f101E93b906
VALIDATOR4_PRIVATE_KEY=7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
VALIDATOR4_PASSWORD=123456

# 验证者5账户配置
VALIDATOR5_ADDRESS=0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
VALIDATOR5_PRIVATE_KEY=47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a
VALIDATOR5_PASSWORD=123456

# 网络配置
NETWORK_ID=202599
CHAIN_ID=202599

# 验证者端口配置
VALIDATOR1_HTTP_PORT=8545
VALIDATOR1_WS_PORT=8546
VALIDATOR1_ENGINE_PORT=8551
VALIDATOR1_P2P_PORT=30301

VALIDATOR2_HTTP_PORT=8553
VALIDATOR2_WS_PORT=8554
VALIDATOR2_ENGINE_PORT=8555
VALIDATOR2_P2P_PORT=30303

VALIDATOR3_HTTP_PORT=8556
VALIDATOR3_WS_PORT=8557
VALIDATOR3_ENGINE_PORT=8558
VALIDATOR3_P2P_PORT=30304

VALIDATOR4_HTTP_PORT=8559
VALIDATOR4_WS_PORT=8560
VALIDATOR4_ENGINE_PORT=8561
VALIDATOR4_P2P_PORT=30305

VALIDATOR5_HTTP_PORT=8562
VALIDATOR5_WS_PORT=8563
VALIDATOR5_ENGINE_PORT=8564
VALIDATOR5_P2P_PORT=30306

# 同步节点端口配置
SYNCNODE_HTTP_PORT=8547
SYNCNODE_WS_PORT=8548
SYNCNODE_ENGINE_PORT=8552
SYNCNODE_P2P_PORT=30302
BOOTNODE_PORT=30300

# 交易池配置
TXPOOL_GLOBAL_SLOTS=12800
TXPOOL_GLOBAL_QUEUE=5120
TXPOOL_LIFETIME=10m0s
TXPOOL_PRICE_LIMIT=1000000000

# 日志级别（0-5, 5为最详细）
VERBOSITY=3

# 内存限制（PM2）
VALIDATOR_MEMORY_LIMIT=2G
SYNCNODE_MEMORY_LIMIT=2G
BOOTNODE_MEMORY_LIMIT=500M
```

## 网络信息

- **Chain ID**: 202599
- **共识算法**: Congress (POA)
- **出块时间**: 1 秒
- **验证者更新周期**: 86400 块

## 系统合约地址

- **Validators**: 0x000000000000000000000000000000000000f000
- **Punish**: 0x000000000000000000000000000000000000f001  
- **Proposal**: 0x000000000000000000000000000000000000f002

## RPC 测试

```bash
# 检查所有验证者的区块高度
for port in 8545 8553 8556 8559 8562; do
  echo "=== Validator on port $port ==="
  curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://localhost:$port | jq -r '.result' | xargs printf "Block: %d\n"
done

# 查看所有验证者账户余额
echo "=== 验证者账户余额 ==="
# Validator1
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","latest"],"id":1}' \
  http://localhost:8545 | jq -r '.result' | xargs printf "Validator1: %d wei\n" 

# Validator2  
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x70997970C51812dc3A010C7d01b50e0d17dc79C8","latest"],"id":1}' \
  http://localhost:8553 | jq -r '.result' | xargs printf "Validator2: %d wei\n"

# Validator3
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC","latest"],"id":1}' \
  http://localhost:8556 | jq -r '.result' | xargs printf "Validator3: %d wei\n"

# Validator4
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x90F79bf6EB2c4f870365E785982E1f101E93b906","latest"],"id":1}' \
  http://localhost:8559 | jq -r '.result' | xargs printf "Validator4: %d wei\n"

# Validator5
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65","latest"],"id":1}' \
  http://localhost:8562 | jq -r '.result' | xargs printf "Validator5: %d wei\n"

# 查看当前验证者列表（通过智能合约）
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0x000000000000000000000000000000000000f000","data":"0x40550a1c000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"},"latest"],"id":1}' \
  http://localhost:8545

# 查看网络连接状态
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545 | jq -r '.result' | xargs printf "Peer count: %d\n"

# 查看最新区块信息
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  http://localhost:8545 | jq '.result | {number, hash, miner, timestamp}'
```

## 性能监控

### 1. 系统资源监控

```bash
# PM2 监控面板
pm2 monit

# 显示进程详细信息
pm2 show ju-chain-validator1

# 内存和 CPU 使用情况
pm2 list

# 使用 htop 监控系统资源
htop
```

### 2. 区块链网络监控

```bash
# 查看区块生产速度（最近10个区块）
./pm2-manager.sh  # 选择挖矿余额分析

# 检查所有节点的同步状态
for port in 8545 8553 8556 8559 8562 8547; do
  echo "Port $port:"
  curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
    http://localhost:$port | jq '.result'
done

# 查看交易池状态
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"txpool_status","params":[],"id":1}' \
  http://localhost:8545 | jq '.result'
```

### 3. 日志分析

```bash
# 搜索错误日志
pm2 logs ju-chain-validator1 --lines 1000 | grep -i error

# 搜索特定时间的日志
pm2 logs ju-chain-validator1 --timestamp --lines 1000 | grep "202599-08-18"

# 实时监控所有日志
pm2 logs --raw | grep -E "(ERROR|WARN|imported|mined)"
```

## 故障排除

### 1. 节点启动失败

```bash
# 检查日志找出具体错误
pm2 logs ju-chain-validator1 --lines 100

# 常见错误及解决方案：
# Error: "bind: address already in use"
lsof -i :8545
pkill -f geth
pm2 delete all

# Error: "Fatal: Could not create the bootnode"  
rm -rf ./private-chain/bootnode/*
./pm2-init.sh

# Error: "datadir already used by another process"
ps aux | grep geth
pkill -f geth
rm -f ./private-chain/data-validator1/geth.ipc

# 完全重新初始化（会清空所有数据）
pm2 delete all
rm -rf ./private-chain/data-validator*/geth
rm -rf ./private-chain/data-sync/geth
./pm2-init.sh
```

### 2. 网络连接问题

```bash
# 检查 P2P 连接
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' \
  http://localhost:8545 | jq '.result | length'

# 检查网络配置
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
  http://localhost:8545 | jq '.result.enode'

# 手动添加节点连接
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_addPeer","params":["enode://...@127.0.0.1:30301"],"id":1}' \
  http://localhost:8553

# 检查防火墙设置
sudo ufw status
sudo iptables -L

# 测试端口连通性
telnet localhost 30301
nc -zv localhost 30301
```

### 3. 性能问题

```bash
# 内存不足 - 调整 PM2 内存限制
pm2 restart ju-chain-validator1 --max-memory-restart 4G

# 磁盘空间不足 - 清理日志
pm2 flush  # 清空所有日志
pm2 install pm2-logrotate  # 安装日志轮转

# CPU 使用率过高 - 调整日志级别
# 编辑 .env 文件，设置 VERBOSITY=1

# 区块同步慢 - 检查网络连接
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545

# 交易处理慢 - 调整交易池配置
# 编辑 .env 文件，增加 TXPOOL_GLOBAL_SLOTS 和 TXPOOL_GLOBAL_QUEUE
```

### 4. 数据恢复

```bash
# 备份关键数据
tar -czf validator-backup-$(date +%Y%m%d).tar.gz ./private-chain/

# 恢复数据
tar -xzf validator-backup-20250818.tar.gz

# 仅备份 keystore（账户密钥）
cp -r ./private-chain/data-validator1/keystore ./keystore-backup/

# 迁移到新环境
rsync -av ./private-chain/ new-server:/path/to/ju-chain-work/chain/private-chain/
```

## 安全注意事项

⚠️ **重要**: 此配置仅用于开发和测试环境

- `.env` 文件包含敏感信息，已添加到 `.gitignore`
- 默认使用测试私钥和密码
- 允许不安全的账户解锁
- HTTP RPC 绑定到 0.0.0.0（所有接口）

生产环境部署时请：

1. 使用安全的密钥管理
2. 配置防火墙和网络安全
3. 使用 HTTPS 和 WSS
4. 定期备份关键数据
5. 修改默认密码和私钥

## 常见问题

### Q: 如何修改端口配置？

A: 编辑 `.env` 文件中的端口配置，然后重启服务：

```bash
nano .env
# 修改相应的端口变量，如：
# VALIDATOR1_HTTP_PORT=8545
# VALIDATOR1_P2P_PORT=30301

pm2 restart all
```

### Q: 如何查看节点详细状态？

A: 使用以下命令获取详细信息：

```bash
# PM2 状态
pm2 status

# 使用管理脚本（推荐）
./pm2-manager.sh

# 查看特定节点日志
pm2 logs ju-chain-validator1 --lines 50

# 检查区块高度和网络状态
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545 | jq -r '.result' | xargs printf "Block: %d\n"
```

### Q: 如何添加新的验证者？

A: 添加新验证者需要以下步骤：

```bash
# 1. 在 .env 文件中添加新验证者配置
VALIDATOR6_ADDRESS=0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc
VALIDATOR6_PRIVATE_KEY=8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
VALIDATOR6_PASSWORD=123456
VALIDATOR6_HTTP_PORT=8565
VALIDATOR6_WS_PORT=8566
VALIDATOR6_ENGINE_PORT=8567
VALIDATOR6_P2P_PORT=30307

# 2. 更新 ecosystem.config.js 添加新节点配置
# 3. 更新 pm2-init.sh 添加新验证者初始化
# 4. 创建对应的 config-validator6.toml 文件
# 5. 重新初始化并启动
```

### Q: 节点启动失败怎么办？

A: 按以下步骤排查：

```bash
# 1. 查看详细日志
pm2 logs ju-chain-validator1 --lines 100

# 2. 检查端口是否被占用
lsof -i :8545
lsof -i :30301

# 3. 停止冲突的进程
pm2 delete all
pkill -f geth

# 4. 检查数据目录权限
ls -la ./private-chain/data-validator1/

# 5. 重新初始化（会清空数据）
rm -rf ./private-chain/data-validator*/geth
./pm2-init.sh

# 6. 逐个启动节点调试
pm2 start ecosystem.config.js --only ju-chain-validator1
```

### Q: 如何备份和恢复数据？

A: 备份恢复操作：

```bash
# 停止所有节点
pm2 stop all

# 备份完整数据
tar -czf ju-chain-backup-$(date +%Y%m%d-%H%M%S).tar.gz ./private-chain/

# 仅备份 keystore（推荐）
mkdir -p ./backup/keystore
for i in {1..5}; do
  cp -r "./private-chain/data-validator$i/keystore" "./backup/keystore/validator$i"
done

# 恢复数据
tar -xzf ju-chain-backup-20250818-143000.tar.gz

# 重启节点
pm2 start ecosystem.config.js
```

### Q: 如何优化性能？

A: 性能优化建议：

```bash
# 1. 调整日志级别（减少 I/O）
echo "VERBOSITY=1" >> .env

# 2. 启用日志轮转
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 7

# 3. 调整交易池大小
echo "TXPOOL_GLOBAL_SLOTS=25600" >> .env
echo "TXPOOL_GLOBAL_QUEUE=10240" >> .env

# 4. 增加内存限制
echo "VALIDATOR_MEMORY_LIMIT=4G" >> .env

# 5. 使用 SSD 存储
# 确保 ./private-chain/ 目录在 SSD 上

# 6. 重启应用更改
pm2 restart all
```

### Q: 端口被占用怎么办？

A: 如果遇到 "bind: address already in use" 错误：

```bash
# 查看占用端口的进程
lsof -i :30301
netstat -tlnp | grep :8545

# 停止占用端口的进程
pkill -f geth
pm2 delete all

# 或者修改 .env 文件中的端口配置
nano .env
# 修改为未使用的端口，如：
# VALIDATOR1_HTTP_PORT=8600
# VALIDATOR1_P2P_PORT=30350

pm2 restart all
```

## 最佳实践

### 1. 日常维护

```bash
# 每日检查脚本
#!/bin/bash
echo "=== Ju Chain 日常检查 $(date) ==="

# 检查 PM2 状态
pm2 status

# 检查区块高度
for port in 8545 8553 8556 8559 8562; do
  height=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://localhost:$port | jq -r '.result' | xargs printf "%d")
  echo "Validator on port $port: Block $height"
done

# 检查日志大小
du -sh ./logs/

# 检查磁盘空间
df -h ./private-chain/
```

### 2. 监控告警

```bash
# 设置资源监控
pm2 install pm2-server-monit

# 内存使用率监控
pm2 monit

# 区块高度监控脚本
#!/bin/bash
current_height=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545 | jq -r '.result' | xargs printf "%d")

if [ $current_height -lt $expected_height ]; then
  echo "警告：区块高度异常！当前高度：$current_height"
  # 发送告警通知
fi
```

### 3. 安全配置

```bash
# 生产环境安全检查清单：
# ✓ 修改默认密码和私钥
# ✓ 限制 RPC 访问 IP（修改 ecosystem.config.js 中的 --http.addr）
# ✓ 启用 HTTPS/WSS
# ✓ 配置防火墙规则
# ✓ 定期备份 keystore
# ✓ 使用专用用户运行服务
# ✓ 启用日志轮转
# ✓ 监控资源使用情况
```

---

## 更多资源

- [Go-Ethereum 官方文档](https://geth.ethereum.org/docs/)
- [PM2 官方文档](https://pm2.keymetrics.io/docs/)
- [Congress 共识机制说明](./docs/congress-consensus.md)
- [智能合约接口文档](./docs/system-contracts.md)

## 技术支持

如遇到问题，请提供以下信息：

- PM2 状态：`pm2 status`
- 错误日志：`pm2 logs ju-chain-validator1 --lines 100`
- 系统信息：`uname -a && free -h && df -h`
