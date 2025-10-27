package core

import (
	"fmt"
	"github.com/holiman/uint256"
	"math"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
)

// 合约 ABI
const blacklistManagerABI = `[
	{
		"inputs": [],
		"name": "getAllBlacklistedAddresses",
		"outputs": [
			{
				"internalType": "address[]",
				"name": "",
				"type": "address[]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "addr",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "AddedToBlacklist",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "address[]",
				"name": "addresses",
				"type": "address[]"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "BatchAddedToBlacklist",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "addr",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "RemovedFromBlacklist",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "address[]",
				"name": "addresses",
				"type": "address[]"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "BatchRemovedFromBlacklist",
		"type": "event"
	}
]`

var (
	// 是否开启黑名单控制功能
	enableBlacklist = false

	// 黑名单管理合约地址
	blacklistContractAddr = common.HexToAddress("0x1db0EDE439708A923431DC68fd3F646c0A4D4e6E")

	// 黑名单变更事件
	eventHashes = make(map[string]common.Hash)

	// 黑名单管理合约调用地址
	blacklistCaller = common.HexToAddress("0x000000000000000000000000000000000000dEaD")

	// 缓存相关
	blacklistCache     = make(map[common.Address]bool)
	blacklistCacheLock sync.RWMutex
	lastUpdateTime     time.Time

	// 定时刷新黑名单
	cacheTimeout = 3 * time.Minute

	parsedABI abi.ABI
)

func initABI() {
	var err error
	parsedABI, err = abi.JSON(strings.NewReader(blacklistManagerABI))
	if err != nil {
		log.Error("Failed to parse blacklist manager ABI", "error", err)
	}

	for _, event := range parsedABI.Events {
		eventHashes[event.Name] = event.ID
	}
}

// InitBlacklist 初始化黑名单功能
func InitBlacklist(blockchain *BlockChain) error {
	if !enableBlacklist {
		return nil
	}

	initABI()

	// 获取当前状态
	stateDB, err := blockchain.State()
	if err != nil {
		return fmt.Errorf("get stateDB: %v", err)
	}

	// 获取当前区块头
	header := blockchain.CurrentHeader()

	// 获取链配置
	chainConfig := blockchain.Config()

	// 初始化黑名单
	if err := readBlacklistFromContract(stateDB, header, chainConfig); err != nil {
		return fmt.Errorf("init blacklist: %v", err)
	}

	// 启动事件监听
	go func() {
		// 订阅事件
		logs := make(chan []*types.Log)
		sub := blockchain.SubscribeLogsEvent(logs)
		defer sub.Unsubscribe()

		for {
			select {
			case err := <-sub.Err():
				log.Error("Blacklist event subscription error", "error", err)
				return
			case vLogs := <-logs:
				eventUpdate(blockchain, vLogs)
			}
		}
	}()

	// 启动定时更新任务
	go func() {
		ticker := time.NewTicker(cacheTimeout)
		defer ticker.Stop()

		for range ticker.C {
			scheduleUpdate(blockchain)
		}
	}()

	log.Info("Blacklist module started")
	return nil
}

// 从合约中读取黑名单地址列表
func readBlacklistFromContract(stateDB *state.StateDB, header *types.Header, chainConfig *params.ChainConfig) error {
	// 打包合约调用数据
	data, err := parsedABI.Pack("getAllBlacklistedAddresses")
	if err != nil {
		return fmt.Errorf("pack data: %v", err)
	}

	// 创建合约调用消息
	msg := Message{
		From:              blacklistCaller,
		To:                &blacklistContractAddr,
		Nonce:             stateDB.GetNonce(blacklistCaller),
		Value:             new(big.Int),
		GasLimit:          math.MaxUint64,
		GasPrice:          new(big.Int),
		GasFeeCap:         new(big.Int),
		GasTipCap:         new(big.Int),
		Data:              data,
		AccessList:        types.AccessList{},
		SkipAccountChecks: true,
	}

	// 执行合约调用
	ret, err := executeMsg(msg, stateDB, header, chainConfig)
	if err != nil {
		return fmt.Errorf("execute msg: %v", err)
	}

	// 解析返回值
	var addresses []common.Address
	if err := parsedABI.UnpackIntoInterface(&addresses, "getAllBlacklistedAddresses", ret); err != nil {
		return fmt.Errorf("unpack result: %v", err)
	}

	blacklistCacheLock.Lock()
	defer blacklistCacheLock.Unlock()

	// 清空旧缓存
	blacklistCache = make(map[common.Address]bool)

	// 更新缓存
	for _, addr := range addresses {
		blacklistCache[addr] = true
	}

	lastUpdateTime = time.Now()
	log.Info("Blacklist updated", "time", lastUpdateTime, "addresses", addresses)
	return nil
}

func executeMsg(msg Message, stateDB *state.StateDB, header *types.Header, chainConfig *params.ChainConfig) ([]byte, error) {
	blockCtx := vm.BlockContext{
		CanTransfer: CanTransfer,
		Transfer:    Transfer,
		GetHash:     func(uint64) common.Hash { return common.Hash{} },
		Coinbase:    header.Coinbase,
		BlockNumber: header.Number,
		Time:        header.Time,
		Difficulty:  header.Difficulty,
		GasLimit:    header.GasLimit,
		BaseFee:     header.BaseFee,
	}
	evm := vm.NewEVM(blockCtx, vm.TxContext{}, stateDB, chainConfig, vm.Config{})
	ret, _, err := evm.Call(
		vm.AccountRef(msg.From),
		*msg.To,
		msg.Data,
		msg.GasLimit,
		uint256.MustFromBig(msg.Value),
	)
	if err != nil {
		return []byte{}, err
	}
	return ret, nil
}

func isEventMatch(topic common.Hash) bool {
	for _, hash := range eventHashes {
		if hash == topic {
			return true
		}
	}
	return false
}

// IsAddressBlacklisted 检查地址是否在黑名单中
func IsAddressBlacklisted(from common.Address, to *common.Address) bool {
	blacklistCacheLock.RLock()
	defer blacklistCacheLock.RUnlock()

	// 检查发送方或接收方是否在黑名单中
	return blacklistCache[from] || (to != nil && blacklistCache[*to])
}

// 定期刷新黑名单
func scheduleUpdate(blockchain *BlockChain) {
	// 获取最新状态
	stateDB, err := blockchain.State()
	if err != nil {
		log.Error("Failed to get stateDB for blacklist update", "error", err)
		return
	}

	// 获取最新区块头
	header := blockchain.CurrentHeader()

	// 更新黑名单
	if err := readBlacklistFromContract(stateDB, header, blockchain.Config()); err != nil {
		log.Error("Failed to update blacklist", "error", err)
	}
}

func eventUpdate(blockchain *BlockChain, vLogs []*types.Log) {
	// 检查是否有黑名单相关事件
	hasBlacklistEvent := false
	for _, vLog := range vLogs {
		if vLog.Address == blacklistContractAddr && len(vLog.Topics) > 0 {
			eventHash := vLog.Topics[0]
			if isEventMatch(eventHash) {
				hasBlacklistEvent = true
				break
			}
		}
	}
	// 如果没有黑名单相关事件，跳过更新
	if !hasBlacklistEvent {
		return
	}

	// 获取最新区块头
	header := blockchain.CurrentHeader()
	currentBlock := header.Number.Uint64()

	// 获取最新状态
	stateDB, err := blockchain.State()
	if err != nil {
		log.Error("Failed to get stateDB for blacklist update", "error", err)
		return
	}

	// 更新黑名单
	if err := readBlacklistFromContract(stateDB, header, blockchain.Config()); err != nil {
		log.Error("Failed to update blacklist after event", "error", err, "blockNumber", currentBlock)
	} else {
		log.Info("Blacklist updated after event", "blockNumber", currentBlock)
	}
}
