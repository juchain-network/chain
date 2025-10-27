# Go Blockchain Development Style Guide

## Go Best Practices

### Type Definitions

- Use `struct` for complex data types
- Use `interface` for behavior contracts  
- Use `type` for custom types and aliases
- Always use proper error handling with explicit error returns

```go
// ✅ Good
type ChainConfig struct {
    ChainID     *big.Int `json:"chainId"`
    NetworkName string   `json:"networkName"`
    GenesisHash common.Hash
}

type ConsensusEngine interface {
    Seal(chain ChainHeaderReader, block *types.Block, results chan<- *types.Block, stop <-chan struct{}) error
    VerifyHeader(chain ChainHeaderReader, header *types.Header, seal bool) error
}

func (c *ChainConfig) Validate() error {
    if c.ChainID == nil {
        return errors.New("chainID cannot be nil")
    }
    return nil
}

// ✅ Constants
const (
    DefaultGasLimit = 8000000
    MaxBlockSize    = 4 * 1024 * 1024 // 4MB
)
```

### Naming Conventions

- Use `PascalCase` for exported functions, types, and variables
- Use `camelCase` for unexported functions and variables
- Use descriptive names that explain purpose
- Follow go-ethereum naming patterns

```go
// ✅ Good
type BlockValidator struct {
    chain   ChainReader
    engine  ConsensusEngine
    config  *ChainConfig
}

func (v *BlockValidator) ValidateBlock(block *types.Block) error {
    return v.validateBlockHeader(block.Header())
}

func (v *BlockValidator) validateBlockHeader(header *types.Header) error {
    // implementation
}

// ❌ Bad
type BlkVal struct {}
func (v *BlkVal) VldBlk() error {}
```

### Error Handling

- Always handle errors explicitly
- Use wrapped errors for context
- Return errors as the last return value
- Use panic only for truly exceptional cases

```go
// ✅ Good error handling
func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
    if len(chain) == 0 {
        return 0, nil
    }
    
    for i, block := range chain {
        if err := bc.validator.ValidateBlock(block); err != nil {
            return i, fmt.Errorf("failed to validate block %d: %w", block.NumberU64(), err)
        }
        
        if err := bc.insertBlock(block); err != nil {
            return i, fmt.Errorf("failed to insert block %d: %w", block.NumberU64(), err)
        }
    }
    
    return len(chain), nil
}
```

### Concurrency Patterns

- Use channels for communication between goroutines
- Use mutexes for protecting shared state
- Use context.Context for cancellation and timeouts
- Avoid data races with proper synchronization

```go
// ✅ Good concurrency
type Miner struct {
    mu     sync.RWMutex
    mining bool
    
    engine   ConsensusEngine
    chain    *BlockChain
    coinbase common.Address
}

func (m *Miner) Start(ctx context.Context) error {
    m.mu.Lock()
    if m.mining {
        m.mu.Unlock()
        return errors.New("miner already started")
    }
    m.mining = true
    m.mu.Unlock()
    
    go m.miningLoop(ctx)
    return nil
}

func (m *Miner) miningLoop(ctx context.Context) {
    ticker := time.NewTicker(3 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            if err := m.mineBlock(ctx); err != nil {
                log.Error("Mining failed", "err", err)
            }
        }
    }
}
```

### Blockchain Specific Patterns

- Use big.Int for large numbers and balances
- Use common.Hash for cryptographic hashes
- Use common.Address for Ethereum addresses
- Follow go-ethereum database patterns

```go
// ✅ Blockchain data types
type Transaction struct {
    Nonce    uint64         `json:"nonce"`
    GasPrice *big.Int       `json:"gasPrice"`
    Gas      uint64         `json:"gas"`
    To       *common.Address `json:"to"`
    Value    *big.Int       `json:"value"`
    Data     []byte         `json:"input"`
    Hash     common.Hash    `json:"hash"`
}

func (tx *Transaction) Cost() *big.Int {
    total := new(big.Int).Mul(tx.GasPrice, new(big.Int).SetUint64(tx.Gas))
    return total.Add(total, tx.Value)
}

// ✅ Database operations
func (db *Database) GetBlock(hash common.Hash) (*types.Block, error) {
    data, err := db.db.Get(blockKey(hash))
    if err != nil {
        if err == leveldb.ErrNotFound {
            return nil, errors.New("block not found")
        }
        return nil, fmt.Errorf("database error: %w", err)
    }
    
    var block types.Block
    if err := rlp.DecodeBytes(data, &block); err != nil {
        return nil, fmt.Errorf("failed to decode block: %w", err)
    }
    
    return &block, nil
}
```

### Testing Patterns

- Use table-driven tests for multiple test cases
- Use proper test setup and teardown
- Mock external dependencies
- Test error conditions

```go
// ✅ Table-driven tests
func TestBlockValidation(t *testing.T) {
    tests := []struct {
        name        string
        block       *types.Block
        wantErr     bool
        expectedErr string
    }{
        {
            name:    "valid block",
            block:   createValidBlock(),
            wantErr: false,
        },
        {
            name:        "invalid gas limit",
            block:       createBlockWithInvalidGas(),
            wantErr:     true,
            expectedErr: "gas limit exceeded",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            validator := NewBlockValidator(nil, nil)
            err := validator.ValidateBlock(tt.block)
            
            if tt.wantErr {
                assert.Error(t, err)
                assert.Contains(t, err.Error(), tt.expectedErr)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

### Documentation

- Use meaningful comments for complex algorithms
- Document public APIs with proper godoc format
- Explain consensus-related logic thoroughly
- Document configuration parameters

```go
// ChainConfig contains the configuration for the blockchain.
// It defines various protocol parameters and hard fork block numbers.
type ChainConfig struct {
    // ChainID identifies the current chain and is used for replay protection
    ChainID *big.Int `json:"chainId"`
    
    // HomesteadBlock is the block number where Homestead hard fork becomes active
    HomesteadBlock *big.Int `json:"homesteadBlock,omitempty"`
}

// IsHomestead returns whether num is either equal to the homestead block or greater.
func (c *ChainConfig) IsHomestead(num *big.Int) bool {
    return isForked(c.HomesteadBlock, num)
}
```
