package core

import (
	"fmt"
	"math"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/holiman/uint256"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
)

// Contract ABI
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
	// Whether to enable blacklist control functionality
	enableBlacklist = true

	// Blacklist management contract address
	blacklistContractAddr = common.HexToAddress("0x1db0EDE439708A923431DC68fd3F646c0A4D4e6E")

	// Blacklist change events
	eventHashes = make(map[string]common.Hash)

	// Blacklist management contract caller address
	blacklistCaller = common.HexToAddress("0x000000000000000000000000000000000000dEaD")

	// Cache related
	blacklistCache     = make(map[common.Address]bool)
	blacklistCacheLock sync.RWMutex
	lastUpdateTime     time.Time

	// Periodically refresh blacklist
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

// InitBlacklist initializes the blacklist functionality
func InitBlacklist(blockchain *BlockChain) error {
	if !enableBlacklist {
		return nil
	}

	initABI()

	// Get current state
	stateDB, err := blockchain.State()
	if err != nil {
		return fmt.Errorf("get stateDB: %v", err)
	}

	// Get current block header
	header := blockchain.CurrentHeader()

	// Get chain configuration
	chainConfig := blockchain.Config()

	// Initialize blacklist
	if err := readBlacklistFromContract(stateDB, header, chainConfig); err != nil {
		return fmt.Errorf("init blacklist: %v", err)
	}

	// Start event listener
	go func() {
		// Subscribe to events
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

	// Start scheduled update task
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

// readBlacklistFromContract reads the blacklist address list from the contract
func readBlacklistFromContract(stateDB *state.StateDB, header *types.Header, chainConfig *params.ChainConfig) error {
	// Pack contract call data
	data, err := parsedABI.Pack("getAllBlacklistedAddresses")
	if err != nil {
		return fmt.Errorf("pack data: %v", err)
	}

	// Create contract call message
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

	// Execute contract call
	ret, err := executeMsg(msg, stateDB, header, chainConfig)
	if err != nil {
		return fmt.Errorf("execute msg: %v", err)
	}

	// Parse return value
	var addresses []common.Address
	if err := parsedABI.UnpackIntoInterface(&addresses, "getAllBlacklistedAddresses", ret); err != nil {
		return fmt.Errorf("unpack result: %v", err)
	}

	blacklistCacheLock.Lock()
	defer blacklistCacheLock.Unlock()

	// Clear old cache
	blacklistCache = make(map[common.Address]bool)

	// Update cache
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

// IsAddressBlacklisted checks if an address is in the blacklist
func IsAddressBlacklisted(from common.Address, to *common.Address) bool {
	blacklistCacheLock.RLock()
	defer blacklistCacheLock.RUnlock()

	// Check if sender or receiver is in the blacklist
	return blacklistCache[from] || (to != nil && blacklistCache[*to])
}

// scheduleUpdate periodically refreshes the blacklist
func scheduleUpdate(blockchain *BlockChain) {
	// Get latest state
	stateDB, err := blockchain.State()
	if err != nil {
		log.Error("Failed to get stateDB for blacklist update", "error", err)
		return
	}

	// Get latest block header
	header := blockchain.CurrentHeader()

	// Update blacklist
	if err := readBlacklistFromContract(stateDB, header, blockchain.Config()); err != nil {
		log.Error("Failed to update blacklist", "error", err)
	}
}

func eventUpdate(blockchain *BlockChain, vLogs []*types.Log) {
	// Check if there are blacklist-related events
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
	// Skip update if no blacklist-related events
	if !hasBlacklistEvent {
		return
	}

	// Get latest block header
	header := blockchain.CurrentHeader()
	currentBlock := header.Number.Uint64()

	// Get latest state
	stateDB, err := blockchain.State()
	if err != nil {
		log.Error("Failed to get stateDB for blacklist update", "error", err)
		return
	}

	// Update blacklist
	if err := readBlacklistFromContract(stateDB, header, blockchain.Config()); err != nil {
		log.Error("Failed to update blacklist after event", "error", err, "blockNumber", currentBlock)
	} else {
		log.Info("Blacklist updated after event", "blockNumber", currentBlock)
	}
}
