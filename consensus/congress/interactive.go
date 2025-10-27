package congress

import (
	"strings"

	"github.com/holiman/uint256"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/consensus"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/params"
)

type chainContext struct {
	chainReader consensus.ChainHeaderReader
	engine      consensus.Engine
}

func newChainContext(chainReader consensus.ChainHeaderReader, engine consensus.Engine) *chainContext {
	return &chainContext{
		chainReader: chainReader,
		engine:      engine,
	}
}

// Engine retrieves the chain's consensus engine.
func (cc *chainContext) Engine() consensus.Engine {
	return cc.engine
}

// Config retrieves the blockchain's chain configuration.
func (cc *chainContext) Config() *params.ChainConfig {
	return cc.chainReader.Config()
}

// GetHeader returns the hash corresponding to their hash.
func (cc *chainContext) GetHeader(hash common.Hash, number uint64) *types.Header {
	return cc.chainReader.GetHeader(hash, number)
}

func getInteractiveABI() map[string]abi.ABI {
	abiMap := make(map[string]abi.ABI, 0)
	tmpABI, _ := abi.JSON(strings.NewReader(validatorsInteractiveABI))
	abiMap[validatorsContractName] = tmpABI
	tmpABI, _ = abi.JSON(strings.NewReader(punishInteractiveABI))
	abiMap[punishContractName] = tmpABI
	tmpABI, _ = abi.JSON(strings.NewReader(proposalInteractiveABI))
	abiMap[proposalContractName] = tmpABI
	tmpABI, _ = abi.JSON(strings.NewReader(stakingInteractiveABI))
	abiMap[stakingContractName] = tmpABI

	return abiMap
}

// executeMsg executes transaction sent to system contracts.
func executeMsg(msg core.Message, state *state.StateDB, header *types.Header, chainContext core.ChainContext, chainConfig *params.ChainConfig) (ret []byte, err error) {
	// Set gas price to zero
	blockContext := core.NewEVMBlockContext(header, chainContext, nil)
	vmenv := vm.NewEVM(blockContext, vm.TxContext{}, state, chainConfig, vm.Config{})

	ret, _, err = vmenv.Call(vm.AccountRef(msg.From), *msg.To, msg.Data, msg.GasLimit, uint256.MustFromBig(msg.Value))

	if err != nil {
		return []byte{}, err
	}

	return ret, nil
}
