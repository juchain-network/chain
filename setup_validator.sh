#!/bin/bash

# 创建验证者账户脚本

echo "🔑 创建 Congress POA 验证者账户"
echo "==============================="

CHAIN_DIR="/Users/enty/ju-chain-work/chain"
DATA_DIR="/Users/enty/ju-chain-work/chain/private-chain/data"
GETH_BIN="$CHAIN_DIR/build/bin/geth"

# 验证者账户信息 (Hardhat 第一个账户)
VALIDATOR_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
VALIDATOR_PRIVATE_KEY="ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

echo "👤 验证者账户: $VALIDATOR_ADDRESS"
echo "💾 数据目录: $DATA_DIR"

# 确保数据目录存在
mkdir -p "$DATA_DIR"

# 创建密码文件
PASSWORD_FILE="$DATA_DIR/password.txt"
echo "123456" > "$PASSWORD_FILE"
echo "✅ 密码文件已创建: $PASSWORD_FILE"

# 导入私钥到 geth
echo "🔐 检查和导入验证者私钥..."

# 检查账户是否已存在
existing_account=$($GETH_BIN account list --datadir "$DATA_DIR" 2>/dev/null | grep -i "${VALIDATOR_ADDRESS#0x}")

if [ -n "$existing_account" ]; then
    echo "✅ 验证者账户已存在，跳过导入"
    echo "$existing_account"
else
    echo "📥 导入验证者私钥..."
    
    # 创建临时私钥文件
    TEMP_KEY_FILE="$DATA_DIR/temp_private_key"
    echo "$VALIDATOR_PRIVATE_KEY" > "$TEMP_KEY_FILE"

    # 导入私钥
    import_result=$($GETH_BIN account import --datadir "$DATA_DIR" --password "$PASSWORD_FILE" "$TEMP_KEY_FILE" 2>&1)
    import_exit_code=$?

    # 删除临时文件
    rm -f "$TEMP_KEY_FILE"

    if [ $import_exit_code -eq 0 ]; then
        echo "✅ 验证者账户导入成功"
        echo "$import_result"
    else
        echo "❌ 验证者账户导入失败"
        echo "$import_result"
        exit 1
    fi
fi

# 列出所有账户
echo ""
echo "📋 当前账户列表:"
$GETH_BIN account list --datadir "$DATA_DIR"

echo ""
echo "🎯 账户设置完成！"
echo "验证者账户: $VALIDATOR_ADDRESS"
echo "密码文件: $PASSWORD_FILE"
echo ""
echo "💡 现在可以运行启动脚本了:"
echo "./start_private_chain.sh"
