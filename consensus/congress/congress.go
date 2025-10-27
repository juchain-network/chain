// Copyright 2017 The go-ethereum Authors
// This file is part of the go-ethereum library.
//
// The go-ethereum library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The go-ethereum library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.

// Package congress implements the proof-of-stake-authority consensus engine.
package congress

import (
	"bytes"
	"errors"
	"io"
	"math/big"
	"math/rand"
	"sort"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/core"

	"github.com/ethereum/go-ethereum/accounts"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/consensus"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethdb"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/ethereum/go-ethereum/trie"
	lru "github.com/hashicorp/golang-lru"
	"github.com/holiman/uint256"
	"golang.org/x/crypto/sha3"
)

const (
	checkpointInterval = 1024 // Number of blocks after which to save the vote snapshot to the database
	inmemorySnapshots  = 128  // Number of recent vote snapshots to keep in memory
	inmemorySignatures = 4096 // Number of recent block signatures to keep in memory

	wiggleTime                    = 500 * time.Millisecond // Random delay (per validator) to allow concurrent validators
	maxValidators                 = 21                     // Max validators allowed to seal.
	systemContractGasLimit        = 100_000_000            // 100M gas limit for system contract calls
	allowedFutureBlockTimeSeconds = int64(10)              // Max seconds from current time allowed for blocks, before they're considered future blocks
)

// Congress proof-of-stake-authority protocol constants.
var (
	epochLength = uint64(86400) // Default number of blocks after which to checkpoint and reset the pending votes

	extraVanity = 32                     // Fixed number of extra-data prefix bytes reserved for validator vanity
	extraSeal   = crypto.SignatureLength // Fixed number of extra-data suffix bytes reserved for validator seal

	uncleHash = types.CalcUncleHash(nil) // Always Keccak256(RLP([])) as uncles are meaningless outside of PoW.

	diffInTurn = big.NewInt(2) // Block difficulty for in-turn signatures
	diffNoTurn = big.NewInt(1) // Block difficulty for out-of-turn signatures

	ether                  = big.NewInt(1e+18)
	AnnualFoundationReward = new(big.Int).Mul(big.NewInt(60_000_000), ether) // Annual foundation reward: 60M JU per year
)

// System contract address.
var (
	validatorsContractName = "validators"
	punishContractName     = "punish"
	proposalContractName   = "proposal"
	stakingContractName    = "staking"
	validatorsContractAddr = common.HexToAddress("0x000000000000000000000000000000000000f000")
	punishContractAddr     = common.HexToAddress("0x000000000000000000000000000000000000f001")
	proposalAddr           = common.HexToAddress("0x000000000000000000000000000000000000f002")
	stakingContractAddr    = common.HexToAddress("0x000000000000000000000000000000000000f003")
)

// Various error messages to mark blocks invalid. These should be private to
// prevent engine specific errors from being referenced in the remainder of the
// codebase, inherently breaking if the engine is swapped out. Please put common
// error types into the consensus package.
var (
	// errUnknownBlock is returned when the list of validators is requested for a block
	// that is not part of the local blockchain.
	errUnknownBlock = errors.New("unknown block")

	// errMissingVanity is returned if a block's extra-data section is shorter than
	// 32 bytes, which is required to store the validator vanity.
	errMissingVanity = errors.New("extra-data 32 byte vanity prefix missing")

	// errMissingSignature is returned if a block's extra-data section doesn't seem
	// to contain a 65 byte secp256k1 signature.
	errMissingSignature = errors.New("extra-data 65 byte signature suffix missing")

	// errExtraValidators is returned if non-checkpoint block contain validator data in
	// their extra-data fields.
	errExtraValidators = errors.New("non-checkpoint block contains extra validator list")

	// errInvalidExtraValidators is returned if validator data in extra-data field is invalid.
	errInvalidExtraValidators = errors.New("invalid extra validators in extra data field")

	// errInvalidCheckpointValidators is returned if a checkpoint block contains an
	// invalid list of validators (i.e. non divisible by 20 bytes).
	errInvalidCheckpointValidators = errors.New("invalid validator list on checkpoint block")

	// errMismatchingCheckpointValidators is returned if a checkpoint block contains a
	// list of validators different than the one the local node calculated.
	errMismatchingCheckpointValidators = errors.New("mismatching validator list on checkpoint block")

	// errInvalidMixDigest is returned if a block's mix digest is non-zero.
	errInvalidMixDigest = errors.New("non-zero mix digest")

	// errInvalidUncleHash is returned if a block contains an non-empty uncle list.
	errInvalidUncleHash = errors.New("non empty uncle hash")

	// errInvalidDifficulty is returned if the difficulty of a block neither 1 or 2.
	errInvalidDifficulty = errors.New("invalid difficulty")

	// errWrongDifficulty is returned if the difficulty of a block doesn't match the
	// turn of the validator.
	errWrongDifficulty = errors.New("wrong difficulty")

	// errInvalidTimestamp is returned if the timestamp of a block is lower than
	// the previous block's timestamp + the minimum block period.
	errInvalidTimestamp = errors.New("invalid timestamp")

	// ErrInvalidTimestamp is returned if the timestamp of a block is lower than
	// the previous block's timestamp + the minimum block period.
	ErrInvalidTimestamp = errors.New("invalid timestamp")

	// errInvalidVotingChain is returned if an authorization list is attempted to
	// be modified via out-of-range or non-contiguous headers.
	errInvalidVotingChain = errors.New("invalid voting chain")

	// errUnauthorizedValidator is returned if a header is signed by a non-authorized entity.
	errUnauthorizedValidator = errors.New("unauthorized validator")

	// errRecentlySigned is returned if a header is signed by an authorized entity
	// that already signed a header recently, thus is temporarily not allowed to.
	errRecentlySigned = errors.New("recently signed")

	// errInvalidValidatorLen is returned if validators length is zero or bigger than maxValidators.
	errInvalidValidatorsLength = errors.New("invalid validators length")

	// errInvalidCoinbase is returned if the coinbase isn't the validator of the block.
	errInvalidCoinbase = errors.New("invalid coinbase")
)

// StateFn gets state by the state root hash.
type StateFn func(hash common.Hash) (*state.StateDB, error)

// ValidatorFn hashes and signs the data to be signed by a backing account.
type ValidatorFn func(validator accounts.Account, mimeType string, message []byte) ([]byte, error)

// ecrecover extracts the Ethereum account address from a signed header.
func ecrecover(header *types.Header, sigcache *lru.ARCCache) (common.Address, error) {
	// If the signature's already cached, return that
	hash := header.Hash()
	if address, known := sigcache.Get(hash); known {
		return address.(common.Address), nil
	}
	// Retrieve the signature from the header extra-data
	if len(header.Extra) < extraSeal {
		return common.Address{}, errMissingSignature
	}
	signature := header.Extra[len(header.Extra)-extraSeal:]

	// Recover the public key and the Ethereum address
	pubkey, err := crypto.Ecrecover(SealHash(header).Bytes(), signature)
	if err != nil {
		return common.Address{}, err
	}
	var validator common.Address
	copy(validator[:], crypto.Keccak256(pubkey[1:])[12:])

	sigcache.Add(hash, validator)
	return validator, nil
}

// Congress is the proof-of-stake-authority consensus engine proposed to support the
// Ethereum testnet following the Ropsten attacks.
type Congress struct {
	chainConfig *params.ChainConfig    // ChainConfig to execute evm
	config      *params.CongressConfig // Consensus engine configuration parameters
	db          ethdb.Database         // Database to store and retrieve snapshot checkpoints

	recents    *lru.ARCCache // Snapshots for recent block to speed up reorgs
	signatures *lru.ARCCache // Signatures of recent blocks to speed up mining

	proposals map[common.Address]bool // Current list of proposals we are pushing

	validator common.Address // Ethereum address of the signing key
	signFn    ValidatorFn    // Validator function to authorize hashes with
	lock      sync.RWMutex   // Protects the validator fields

	stateFn StateFn // Function to get state by state root

	abi map[string]abi.ABI // Interactive with system contracts

	// The fields below are for testing only
	fakeDiff bool // Skip difficulty verifications
}

// New creates a Congress proof-of-stake-authority consensus engine with the initial
// validators set to the ones provided by the user.
func New(chainConfig *params.ChainConfig, db ethdb.Database) *Congress {
	// Set any missing consensus parameters to their defaults
	conf := *chainConfig.Congress
	if conf.Epoch == 0 {
		conf.Epoch = epochLength
	}
	// Allocate the snapshot caches and create the engine
	recents, _ := lru.NewARC(inmemorySnapshots)
	signatures, _ := lru.NewARC(inmemorySignatures)

	abi := getInteractiveABI()

	return &Congress{
		chainConfig: chainConfig,
		config:      &conf,
		db:          db,
		recents:     recents,
		signatures:  signatures,
		proposals:   make(map[common.Address]bool),
		abi:         abi,
	}
}

// SetStateFn sets the function to get state.
func (c *Congress) SetStateFn(fn StateFn) {
	c.stateFn = fn
}

// Author implements consensus.Engine, returning the Ethereum address recovered
// from the signature in the header's extra-data section.
func (c *Congress) Author(header *types.Header) (common.Address, error) {
	return header.Coinbase, nil
	// return ecrecover(header, c.signatures)
}

// VerifyHeader checks whether a header conforms to the consensus rules.
func (c *Congress) VerifyHeader(chain consensus.ChainHeaderReader, header *types.Header) error {
	return c.verifyHeader(chain, header, nil)
}

// VerifyHeaders is similar to VerifyHeader, but verifies a batch of headers. The
// method returns a quit channel to abort the operations and a results channel to
// retrieve the async verifications (the order is that of the input slice).
func (c *Congress) VerifyHeaders(chain consensus.ChainHeaderReader, headers []*types.Header) (chan<- struct{}, <-chan error) {
	abort := make(chan struct{})
	results := make(chan error, len(headers))

	go func() {
		for i, header := range headers {
			err := c.verifyHeader(chain, header, headers[:i])

			select {
			case <-abort:
				return
			case results <- err:
			}
		}
	}()
	return abort, results
}

// verifyHeader checks whether a header conforms to the consensus rules.The
// caller may optionally pass in a batch of parents (ascending order) to avoid
// looking those up from the database. This is useful for concurrently verifying
// a batch of new headers.
func (c *Congress) verifyHeader(chain consensus.ChainHeaderReader, header *types.Header, parents []*types.Header) error {
	if header.Number == nil {
		return errUnknownBlock
	}
	number := header.Number.Uint64()

	// Don't waste time checking blocks from the future
	// But be more lenient to avoid stopping the chain due to minor time differences
	futureThreshold := uint64(time.Now().Unix() + allowedFutureBlockTimeSeconds)
	if header.Time > futureThreshold {
		// Log the time difference for debugging
		timeDiff := int64(header.Time) - time.Now().Unix()
		log.Debug("Block from future detected",
			"blockTime", header.Time,
			"currentTime", time.Now().Unix(),
			"difference", timeDiff,
			"threshold", allowedFutureBlockTimeSeconds,
			"blockNumber", header.Number.Uint64())

		// Only reject if the difference is significant (more than threshold)
		if timeDiff > allowedFutureBlockTimeSeconds {
			return consensus.ErrFutureBlock
		}
	}
	// Check that the extra-data contains the vanity, validators and signature.
	if len(header.Extra) < extraVanity {
		return errMissingVanity
	}
	if len(header.Extra) < extraVanity+extraSeal {
		return errMissingSignature
	}
	// check extra data
	isEpoch := number%c.config.Epoch == 0

	// Ensure that the extra-data contains a validator list on checkpoint, but none otherwise
	validatorsBytes := len(header.Extra) - extraVanity - extraSeal
	if !isEpoch && validatorsBytes != 0 {
		return errExtraValidators
	}
	// Ensure that the validator bytes length is valid
	if isEpoch && validatorsBytes%common.AddressLength != 0 {
		return errExtraValidators
	}

	// For epoch blocks, validate validator count and prevent empty validator sets
	if isEpoch {
		validatorCount := validatorsBytes / common.AddressLength
		if validatorCount == 0 || validatorCount > maxValidators {
			return errInvalidValidatorsLength
		}

		// Verify that the validator set in header matches the one derived from contract state
		// This prevents light clients from accepting malicious validator sets
		if number > 0 && c.stateFn != nil {
			if err := c.verifyEpochValidators(chain, header, parents); err != nil {
				return err
			}
		}
	}

	// Ensure that the mix digest is zero as we don't have fork protection currently
	if header.MixDigest != (common.Hash{}) {
		return errInvalidMixDigest
	}
	// Ensure that the block doesn't contain any uncles which are meaningless in PoA
	if header.UncleHash != uncleHash {
		return errInvalidUncleHash
	}
	// Ensure that the block's difficulty is meaningful (may not be correct at this point)
	if number > 0 && header.Difficulty == nil {
		return errInvalidDifficulty
	}
	// If all checks passed, validate any special fields for hard forks
	// This part of the logic can be removed to maintain compatibility with existing code
	//if err := misc.VerifyForkHashes(chain.Config(), header, false); err != nil {
	//	return err
	//}
	// All basic checks passed, verify cascading fields
	return c.verifyCascadingFields(chain, header, parents)
}

// verifyCascadingFields verifies all the header fields that are not standalone,
// rather depend on a batch of previous headers. The caller may optionally pass
// in a batch of parents (ascending order) to avoid looking those up from the
// database. This is useful for concurrently verifying a batch of new headers.
func (c *Congress) verifyCascadingFields(chain consensus.ChainHeaderReader, header *types.Header, parents []*types.Header) error {
	// The genesis block is the always valid dead-end
	number := header.Number.Uint64()
	if number == 0 {
		return nil
	}

	var parent *types.Header
	if len(parents) > 0 {
		parent = parents[len(parents)-1]
	} else {
		parent = chain.GetHeader(header.ParentHash, number-1)
	}
	if parent == nil || parent.Number.Uint64() != number-1 || parent.Hash() != header.ParentHash {
		return consensus.ErrUnknownAncestor
	}

	if parent.Time+c.config.Period > header.Time {
		return ErrInvalidTimestamp
	}

	// Verify Shanghai upgrade - check if WithdrawalsHash is included
	if c.chainConfig.IsShanghai(header.Number, header.Time) {
		if header.WithdrawalsHash == nil {
			return errors.New("missing withdrawalsHash post-Shanghai")
		}
	}

	// All basic checks passed, verify the seal and return
	return c.verifySeal(chain, header, parents)
}

// verifyEpochValidators verifies that the validator set in epoch block header
// matches the one derived from the contract state at parent block
func (c *Congress) verifyEpochValidators(chain consensus.ChainHeaderReader, header *types.Header, parents []*types.Header) error {
	var parent *types.Header
	number := header.Number.Uint64()

	if len(parents) > 0 {
		parent = parents[len(parents)-1]
	} else {
		parent = chain.GetHeader(header.ParentHash, number-1)
	}
	if parent == nil {
		return consensus.ErrUnknownAncestor
	}

	// Get expected validators from contract state using parent block state
	expectedValidators, err := c.getTopValidatorsAtParent(parent, chain)
	if err != nil {
		log.Warn("Failed to get expected validators from contract", "err", err)
		return err
	}

	// Extract validators from header
	validatorsBytes := len(header.Extra) - extraVanity - extraSeal
	headerValidators := make([]common.Address, validatorsBytes/common.AddressLength)
	for i := 0; i < len(headerValidators); i++ {
		copy(headerValidators[i][:], header.Extra[extraVanity+i*common.AddressLength:])
	}

	// Sort both sets for comparison
	sort.Slice(expectedValidators, func(i, j int) bool {
		return expectedValidators[i].Hex() < expectedValidators[j].Hex()
	})
	sort.Slice(headerValidators, func(i, j int) bool {
		return headerValidators[i].Hex() < headerValidators[j].Hex()
	})

	// Compare validator sets
	if len(expectedValidators) != len(headerValidators) {
		log.Warn("Validator count mismatch", "expected", len(expectedValidators), "header", len(headerValidators))
		return errMismatchingCheckpointValidators
	}

	for i, expected := range expectedValidators {
		if expected != headerValidators[i] {
			log.Warn("Validator mismatch at index", "index", i, "expected", expected.Hex(), "header", headerValidators[i].Hex())
			return errMismatchingCheckpointValidators
		}
	}

	return nil
}

// getTopValidatorsAtParent gets validators from contract using the parent block state
func (c *Congress) getTopValidatorsAtParent(parent *types.Header, chain consensus.ChainHeaderReader) ([]common.Address, error) {
	if c.stateFn == nil {
		return nil, errors.New("stateFn not set")
	}

	statedb, err := c.stateFn(parent.Root)
	if err != nil {
		return nil, err
	}

	method := "getTopValidators"
	data, err := c.abi[validatorsContractName].Pack(method)
	if err != nil {
		return nil, err
	}

	msg := newMessage(parent.Coinbase, &validatorsContractAddr, 0, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)

	// Use newChainContext to create proper context
	chainContext := newChainContext(chain, c)
	result, err := executeMsg(msg, statedb, parent, chainContext, c.chainConfig)
	if err != nil {
		return nil, err
	}

	// unpack data
	ret, err := c.abi[validatorsContractName].Unpack(method, result)
	if err != nil {
		return nil, err
	}
	if len(ret) != 1 {
		return nil, errors.New("invalid params length")
	}
	validators, ok := ret[0].([]common.Address)
	if !ok {
		return nil, errors.New("invalid validators format")
	}

	return validators, nil
}

// snapshot retrieves the authorization snapshot at a given point in time.
func (c *Congress) snapshot(chain consensus.ChainHeaderReader, number uint64, hash common.Hash, parents []*types.Header) (*Snapshot, error) {
	// Search for a snapshot in memory or on disk for checkpoints
	var (
		headers []*types.Header
		snap    *Snapshot
	)
	for {
		// If an in-memory snapshot was found, use that
		if s, ok := c.recents.Get(hash); ok {
			snap = s.(*Snapshot)
			break
		}
		// If an on-disk checkpoint snapshot can be found, use that
		if number%checkpointInterval == 0 {
			if s, err := loadSnapshot(c.config, c.signatures, c.db, hash); err == nil {
				log.Trace("Loaded voting snapshot from disk", "number", number, "hash", hash)
				snap = s
				break
			}
		}
		// If we're at the genesis, snapshot the initial state. Alternatively if we're
		// at a checkpoint block without a parent (light client CHT), or we have piled
		// up more headers than allowed to be reorged (chain reinit from a freezer),
		// consider the checkpoint trusted and snapshot it.
		if number == 0 || (number%c.config.Epoch == 0 && (len(headers) > params.FullImmutabilityThreshold || chain.GetHeaderByNumber(number-1) == nil)) {
			checkpoint := chain.GetHeaderByNumber(number)
			if checkpoint != nil {
				hash := checkpoint.Hash()

				validators := make([]common.Address, (len(checkpoint.Extra)-extraVanity-extraSeal)/common.AddressLength)
				for i := 0; i < len(validators); i++ {
					copy(validators[i][:], checkpoint.Extra[extraVanity+i*common.AddressLength:])
				}
				snap = newSnapshot(c.config, c.signatures, number, hash, validators)
				if err := snap.store(c.db); err != nil {
					return nil, err
				}
				log.Info("Stored checkpoint snapshot to disk", "number", number, "hash", hash)
				break
			}
		}
		// No snapshot for this header, gather the header and move backward
		var header *types.Header
		if len(parents) > 0 {
			// If we have explicit parents, pick from there (enforced)
			header = parents[len(parents)-1]
			if header.Hash() != hash || header.Number.Uint64() != number {
				return nil, consensus.ErrUnknownAncestor
			}
			parents = parents[:len(parents)-1]
		} else {
			// No explicit parents (or no more left), reach out to the database
			header = chain.GetHeader(hash, number)
			if header == nil {
				return nil, consensus.ErrUnknownAncestor
			}
		}
		headers = append(headers, header)
		number, hash = number-1, header.ParentHash
	}
	// Previous snapshot found, apply any pending headers on top of it
	for i := 0; i < len(headers)/2; i++ {
		headers[i], headers[len(headers)-1-i] = headers[len(headers)-1-i], headers[i]
	}
	snap, err := snap.apply(headers, chain, parents)
	if err != nil {
		return nil, err
	}
	c.recents.Add(snap.Hash, snap)

	// If we've generated a new checkpoint snapshot, save to disk
	if snap.Number%checkpointInterval == 0 && len(headers) > 0 {
		if err = snap.store(c.db); err != nil {
			return nil, err
		}
		log.Trace("Stored voting snapshot to disk", "number", snap.Number, "hash", snap.Hash)
	}
	return snap, err
}

// VerifyUncles implements consensus.Engine, always returning an error for any
// uncles as this consensus mechanism doesn't permit uncles.
func (c *Congress) VerifyUncles(chain consensus.ChainReader, block *types.Block) error {
	if len(block.Uncles()) > 0 {
		return errors.New("uncles not allowed")
	}
	return nil
}

// VerifySeal implements consensus.Engine, checking whether the signature contained
// in the header satisfies the consensus protocol requirements.
func (c *Congress) VerifySeal(chain consensus.ChainHeaderReader, header *types.Header) error {
	return c.verifySeal(chain, header, nil)
}

// verifySeal checks whether the signature contained in the header satisfies the
// consensus protocol requirements. The method accepts an optional list of parent
// headers that aren't yet part of the local blockchain to generate the snapshots
// from.
func (c *Congress) verifySeal(chain consensus.ChainHeaderReader, header *types.Header, parents []*types.Header) error {
	// Verifying the genesis block is not supported
	number := header.Number.Uint64()
	if number == 0 {
		return errUnknownBlock
	}
	// Retrieve the snapshot needed to verify this header and cache it
	snap, err := c.snapshot(chain, number-1, header.ParentHash, parents)
	if err != nil {
		return err
	}

	// Resolve the authorization key and check against validators
	signer, err := ecrecover(header, c.signatures)
	if err != nil {
		return err
	}
	if signer != header.Coinbase {
		return errInvalidCoinbase
	}

	if _, ok := snap.Validators[signer]; !ok {
		return errUnauthorizedValidator
	}

	for seen, recent := range snap.Recents {
		if recent == signer {
			// Validator is among recents, only fail if the current block doesn't shift it out
			if limit := uint64(len(snap.Validators)/2 + 1); seen > number-limit {
				return errRecentlySigned
			}
		}
	}

	// Ensure that the difficulty corresponds to the turn-ness of the signer
	if !c.fakeDiff {
		inturn := snap.inturn(header.Number.Uint64(), signer)
		if inturn && header.Difficulty.Cmp(diffInTurn) != 0 {
			return errWrongDifficulty
		}
		if !inturn && header.Difficulty.Cmp(diffNoTurn) != 0 {
			return errWrongDifficulty
		}
	}

	return nil
}

// Prepare implements consensus.Engine, preparing all the consensus fields of the
// header for running the transactions on top.
func (c *Congress) Prepare(chain consensus.ChainHeaderReader, header *types.Header) error {
	// If the block isn't a checkpoint, cast a random vote (good enough for now)
	header.Coinbase = c.validator
	header.Nonce = types.BlockNonce{}

	number := header.Number.Uint64()
	snap, err := c.snapshot(chain, number-1, header.ParentHash, nil)
	if err != nil {
		return err
	}

	// Set the correct difficulty
	header.Difficulty = calcDifficulty(snap, c.validator)

	// Ensure the extra data has all its components
	if len(header.Extra) < extraVanity {
		header.Extra = append(header.Extra, bytes.Repeat([]byte{0x00}, extraVanity-len(header.Extra))...)
	}
	header.Extra = header.Extra[:extraVanity]

	if number%c.config.Epoch == 0 {
		newSortedValidators, err := c.getTopValidators(chain, header)
		if err != nil {
			return err
		}

		for _, validator := range newSortedValidators {
			header.Extra = append(header.Extra, validator.Bytes()...)
		}
	}
	header.Extra = append(header.Extra, make([]byte, extraSeal)...)

	// Mix digest is reserved for now, set to empty
	header.MixDigest = common.Hash{}

	// Ensure the timestamp has the correct delay
	parent := chain.GetHeader(header.ParentHash, number-1)
	if parent == nil {
		return consensus.ErrUnknownAncestor
	}
	header.Time = parent.Time + c.config.Period
	if header.Time < uint64(time.Now().Unix()) {
		header.Time = uint64(time.Now().Unix())
	}

	// Process block header information after fork
	// After Shanghai fork, WithdrawalsHash must be set (even if nil)
	if c.chainConfig.IsShanghai(header.Number, header.Time) {
		if header.WithdrawalsHash == nil {
			header.WithdrawalsHash = &types.EmptyWithdrawalsHash
		}
	}
	// Critical fix: Initialize Cancun related fields
	if c.chainConfig.IsCancun(header.Number, header.Time) {
		if header.ExcessBlobGas == nil {
			header.ExcessBlobGas = new(uint64)
		}
		if header.BlobGasUsed == nil {
			header.BlobGasUsed = new(uint64)
		}
	}
	return nil
}

// Finalize implements consensus.Engine, ensuring no uncles are set, nor block rewards given.
func (c *Congress) Finalize(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB, txs []*types.Transaction, uncles []*types.Header, withdrawals []*types.Withdrawal) error {
	// Initialize all system contracts at block 1.
	if header.Number.Cmp(common.Big1) == 0 {
		if err := c.initializeSystemContracts(chain, header, state); err != nil {
			log.Error("Initialize system contracts failed", "err", err)
			return err
		}
	}

	if header.Difficulty.Cmp(diffInTurn) != 0 {
		if err := c.punishOutOfTurnValidator(chain, header, state); err != nil {
			return err
		}
	}

	// execute block fee reward tx.
	if len(txs) > 0 {
		if err := c.distributeFeeReward(chain, header, state); err != nil {
			log.Error("Finalize distributeFeeReward failed",
				"err", err,
				"block", header.Number.Uint64(),
				"coinbase", header.Coinbase.Hex(),
				"txCount", len(txs),
				"gasUsed", header.GasUsed,
				"function", "distributeFeeReward")
			return err
		}
	}

	// JPoSA: Always distribute base block reward
	if err := c.distributeCoinbaseReward(chain, header, state); err != nil {
		return err
	}

	// do epoch thing at the end, because it will update active validators
	if header.Number.Uint64()%c.config.Epoch == 0 {
		newValidators, err := c.handleEpochTransition(chain, header, state)
		if err != nil {
			return err
		}

		validatorsBytes := make([]byte, len(newValidators)*common.AddressLength)
		for i, validator := range newValidators {
			copy(validatorsBytes[i*common.AddressLength:], validator.Bytes())
		}

		extraSuffix := len(header.Extra) - extraSeal
		if !bytes.Equal(header.Extra[extraVanity:extraSuffix], validatorsBytes) {
			return errInvalidExtraValidators
		}
	}

	// Note: Annual foundation reward distribution is handled only in FinalizeAndAssemble
	// during mining to prevent double spending during block validation

	// No block rewards in PoA, so the state remains as is and uncles are dropped
	header.Root = state.IntermediateRoot(chain.Config().IsEIP158(header.Number))
	header.UncleHash = types.CalcUncleHash(nil)

	// After Shanghai upgrade, if block contains withdrawal operations, calculate actual WithdrawalsHash
	if c.chainConfig.IsShanghai(header.Number, header.Time) {
		if withdrawals != nil {
			withdrawalsRoot := types.DeriveSha(types.Withdrawals(withdrawals), trie.NewStackTrie(nil))
			header.WithdrawalsHash = &withdrawalsRoot
		} else {
			// Note: Empty withdrawals also need an empty hash!
			header.WithdrawalsHash = &types.EmptyWithdrawalsHash
		}
	}
	return nil
}

// FinalizeAndAssemble implements consensus.Engine, ensuring no uncles are set, nor block rewards given, and returns the final block.
func (c *Congress) FinalizeAndAssemble(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB, txs []*types.Transaction, uncles []*types.Header, receipts []*types.Receipt, withdrawals []*types.Withdrawal) (*types.Block, error) {
	// Initialize all system contracts at block 1.
	if header.Number.Cmp(common.Big1) == 0 {
		if err := c.initializeSystemContracts(chain, header, state); err != nil {
			log.Error("Initialize system contracts failed", "err", err)
			return nil, err
		}
	}

	// punish validator if necessary
	if header.Difficulty.Cmp(diffInTurn) != 0 {
		if err := c.punishOutOfTurnValidator(chain, header, state); err != nil {
			log.Error("Try punish validator failed", "err", err)
			return nil, err
		}
	}

	// deposit block reward if any tx exists.
	if len(txs) > 0 {
		if err := c.distributeFeeReward(chain, header, state); err != nil {
			log.Error("FinalizeAndAssemble distributeFeeReward failed",
				"err", err,
				"block", header.Number.Uint64(),
				"coinbase", header.Coinbase.Hex(),
				"txCount", len(txs),
				"gasUsed", header.GasUsed,
				"function", "distributeFeeReward")
			return nil, err
		}
	}

	// JPoSA: Always distribute base block reward
	if err := c.distributeCoinbaseReward(chain, header, state); err != nil {
		log.Error("Distribute base block reward failed", "err", err)
		return nil, err
	}

	// do epoch thing at the end, because it will update active validators
	if header.Number.Uint64()%c.config.Epoch == 0 {
		if _, err := c.handleEpochTransition(chain, header, state); err != nil {
			log.Error("Do something at epoch failed", "err", err)
			return nil, err
		}
	}

	if header.Number.Uint64() > 1 {
		// get receiver addr and period from contract
		receiverAddr, err := c.getReceiverAddr(chain, header)
		if err != nil {
			log.Error("Get receiver addr failed", "err", err)
			return nil, err
		}
		increasePeriod, err := c.getIncreasePeriod(chain, header)
		if err != nil {
			log.Error("Get increase period failed", "err", err)
			return nil, err
		}
		if header.Number.Uint64()%increasePeriod.Uint64() == 0 {
			annualRewardUint256, _ := uint256.FromBig(AnnualFoundationReward)
			state.AddBalance(receiverAddr, annualRewardUint256)
			log.Info("Annual foundation reward distributed", "amount", AnnualFoundationReward, "receiverAddr", receiverAddr)
		}
	}

	// No block rewards in PoA, so the state remains as is and uncles are dropped
	header.Root = state.IntermediateRoot(chain.Config().IsEIP158(header.Number))
	header.UncleHash = types.CalcUncleHash(nil)

	// Assemble and return the final block for sealing

	//return types.NewBlock(header, txs, nil, receipts, new(trie.Trie)), nil
	// Modify Trie object creation to avoid panic
	// After Shanghai fork, withdrawals need to be included
	if c.chainConfig.IsShanghai(header.Number, header.Time) {
		tmp := withdrawals
		if tmp == nil {
			// Need to set as empty array, otherwise EmptyWithdrawalsHash won't be calculated
			tmp = []*types.Withdrawal{}
		}
		return types.NewBlockWithWithdrawals(header, txs, nil, receipts, tmp, trie.NewStackTrie(nil)), nil
	}
	return types.NewBlock(header, txs, nil, receipts, trie.NewStackTrie(nil)), nil
}

func (c *Congress) distributeFeeReward(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	fee := state.GetBalance(params.FeeRecorder)
	log.Debug("distributeFeeReward called",
		"block", header.Number.Uint64(),
		"coinbase", header.Coinbase.Hex(),
		"feeAmount", fee.String())

	if fee.Cmp(common.U2560) <= 0 {
		log.Debug("No fees to distribute", "feeAmount", fee.String())
		return nil
	}

	// Miner will send tx to deposit block fees to contract, add to his balance first.
	state.AddBalance(header.Coinbase, fee)
	// reset fee
	state.SetBalance(params.FeeRecorder, common.U2560)

	method := "distributeBlockReward"
	data, err := c.abi[validatorsContractName].Pack(method)
	if err != nil {
		log.Error("Can't pack data for distributeBlockReward",
			"err", err,
			"method", method,
			"contract", validatorsContractAddr.Hex())
		return err
	}

	nonce := state.GetNonce(header.Coinbase)
	log.Debug("Calling distributeBlockReward contract",
		"contract", validatorsContractAddr.Hex(),
		"from", header.Coinbase.Hex(),
		"nonce", nonce,
		"value", fee.String(),
		"gasLimit", systemContractGasLimit)

	msg := newMessage(header.Coinbase, &validatorsContractAddr, nonce, fee.ToBig(), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)
	if _, err := executeMsg(msg, state, header, newChainContext(chain, c), c.chainConfig); err != nil {
		log.Error("distributeBlockReward contract execution failed",
			"err", err,
			"contract", validatorsContractAddr.Hex(),
			"from", header.Coinbase.Hex(),
			"value", fee.String(),
			"gasLimit", systemContractGasLimit,
			"block", header.Number.Uint64())
		return err
	}

	log.Debug("Fee reward distributed successfully",
		"block", header.Number.Uint64(),
		"amount", fee.String(),
		"coinbase", header.Coinbase.Hex())
	return nil
}

func (c *Congress) distributeCoinbaseReward(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	// Skip base reward for genesis block
	if header.Number.Uint64() == 0 {
		return nil
	}

	var baseReward *big.Int

	// Check if PoSA hard fork is active
	if c.chainConfig.IsPosaMerge(header.Number, header.Time) {
		// Post-fork: Base block reward: 0.833 JU per block (target: 72,000 JU/day)
		// 72,000 JU/day ÷ 86,400 blocks/day = 0.833... JU/block
		// Using 833/1000 ratio for precision: 833 * 1e18 / 1000
		baseReward = new(big.Int).Mul(big.NewInt(833), new(big.Int).Exp(big.NewInt(10), big.NewInt(15), nil)) // 0.833 JU
	} else {
		// Pre-fork: Original block reward: 2 JU per block
		ether := new(big.Int).Exp(big.NewInt(10), big.NewInt(18), nil)
		baseReward = new(big.Int).Mul(big.NewInt(2), ether) // 2 JU
	}

	baseRewardUint256, _ := uint256.FromBig(baseReward)

	// Check if JPoSA (staking) is enabled
	if c.isJPoSAEnabled(header.Number) {
		// Use Validators contract for reward distribution (similar to distributeFeeReward)
		log.Debug("distributeCoinbaseReward with validators contract called",
			"block", header.Number.Uint64(),
			"coinbase", header.Coinbase.Hex(),
			"baseReward", baseReward.String())

		// Add reward balance to coinbase first (miner will send tx to contract)
		state.AddBalance(header.Coinbase, baseRewardUint256)

		// Call validators contract to distribute block rewards
		method := "distributeBlockReward"
		data, err := c.abi[validatorsContractName].Pack(method)
		if err != nil {
			log.Error("Can't pack data for distributeBlockReward",
				"err", err,
				"method", method,
				"contract", validatorsContractAddr.Hex())
			// Fallback to direct distribution if contract call fails
			log.Debug("Fallback: Direct PoSA block reward distributed", "amount", baseReward, "recipient", header.Coinbase.Hex(), "block", header.Number.Uint64())
			return nil
		}

		nonce := state.GetNonce(header.Coinbase)
		log.Debug("Calling distributeBlockReward validators contract",
			"contract", validatorsContractAddr.Hex(),
			"from", header.Coinbase.Hex(),
			"nonce", nonce,
			"value", baseReward.String(),
			"gasLimit", systemContractGasLimit)

		msg := newMessage(header.Coinbase, &validatorsContractAddr, nonce, baseReward, systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)
		if _, err := executeMsg(msg, state, header, newChainContext(chain, c), c.chainConfig); err != nil {
			log.Error("distributeBlockReward validators contract execution failed",
				"err", err,
				"contract", validatorsContractAddr.Hex(),
				"from", header.Coinbase.Hex(),
				"value", baseReward.String(),
				"gasLimit", systemContractGasLimit,
				"block", header.Number.Uint64())
			// Don't return error, just log and continue with direct distribution
			log.Debug("Fallback: Direct PoSA block reward distributed", "amount", baseReward, "recipient", header.Coinbase.Hex(), "block", header.Number.Uint64())
			return nil
		}

		log.Debug("Validators-based block reward distributed successfully",
			"block", header.Number.Uint64(),
			"amount", baseReward.String(),
			"validator", header.Coinbase.Hex())
	} else {
		// Pre-fork: traditional mining reward - direct distribution
		state.AddBalance(header.Coinbase, baseRewardUint256)
		log.Debug("Traditional mining reward distributed", "amount", baseReward, "miner", header.Coinbase.Hex(), "block", header.Number.Uint64())
	}

	log.Debug("Base block reward distributed", "amount", baseReward, "block", header.Number.Uint64(), "coinbase", header.Coinbase.Hex())
	return nil
}

func (c *Congress) punishOutOfTurnValidator(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	number := header.Number.Uint64()
	snap, err := c.snapshot(chain, number-1, header.ParentHash, nil)
	if err != nil {
		return err
	}
	validators := snap.validators()
	outTurnValidator := validators[number%uint64(len(validators))]
	// check sigend recently or not
	signedRecently := false
	for _, recent := range snap.Recents {
		if recent == outTurnValidator {
			signedRecently = true
			break
		}
	}
	if !signedRecently {
		if err := c.punishValidator(outTurnValidator, chain, header, state); err != nil {
			return err
		}
	}

	return nil
}

func (c *Congress) handleEpochTransition(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) ([]common.Address, error) {
	newSortedValidators, err := c.getTopValidators(chain, header)
	if err != nil {
		return []common.Address{}, err
	}

	// update contract new validators if new set exists
	if err := c.updateValidators(newSortedValidators, chain, header, state); err != nil {
		return []common.Address{}, err
	}
	//  decrease validator missed blocks counter at epoch
	if err := c.decreaseMissedBlocksCounter(chain, header, state); err != nil {
		return []common.Address{}, err
	}

	return newSortedValidators, nil
}

// initializeSystemContracts initializes all system contracts.
func (c *Congress) initializeSystemContracts(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	snap, err := c.snapshot(chain, 0, header.ParentHash, nil)
	if err != nil {
		return err
	}

	genesisValidators := snap.validators()
	if len(genesisValidators) == 0 || len(genesisValidators) > maxValidators {
		return errInvalidValidatorsLength
	}

	method := "initialize"
	contracts := []struct {
		addr    common.Address
		packFun func() ([]byte, error)
	}{
		{validatorsContractAddr, func() ([]byte, error) {
			return c.abi[validatorsContractName].Pack(method, genesisValidators, proposalAddr, punishContractAddr, stakingContractAddr)
		}},
		{punishContractAddr, func() ([]byte, error) {
			return c.abi[punishContractName].Pack(method, validatorsContractAddr, proposalAddr)
		}},
		{proposalAddr, func() ([]byte, error) {
			return c.abi[proposalContractName].Pack(method, genesisValidators, validatorsContractAddr)
		}},
		{stakingContractAddr, func() ([]byte, error) {
			return c.abi[stakingContractName].Pack(method, validatorsContractAddr)
		}},
	}

	for _, contract := range contracts {
		data, err := contract.packFun()
		if err != nil {
			return err
		}

		nonce := state.GetNonce(header.Coinbase)
		msg := newMessage(header.Coinbase, &contract.addr, nonce, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)

		if _, err := executeMsg(msg, state, header, newChainContext(chain, c), c.chainConfig); err != nil {
			return err
		}
	}

	return nil
}

// get receiver addr
func (c *Congress) getReceiverAddr(chain consensus.ChainHeaderReader, header *types.Header) (common.Address, error) {
	parent := chain.GetHeader(header.ParentHash, header.Number.Uint64()-1)
	if parent == nil {
		return common.Address{}, consensus.ErrUnknownAncestor
	}
	statedb, err := c.stateFn(parent.Root)
	if err != nil {
		return common.Address{}, err
	}
	method := "receiverAddr"
	data, err := c.abi[proposalContractName].Pack(method)
	if err != nil {
		log.Error("Can't pack data for receiverAddr", "error", err)
		return common.Address{}, err
	}

	msg := newMessage(header.Coinbase, &proposalAddr, 0, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)

	// use parent
	result, err := executeMsg(msg, statedb, parent, newChainContext(chain, c), c.chainConfig)
	if err != nil {
		return common.Address{}, err
	}

	// unpack data
	ret, err := c.abi[proposalContractName].Unpack(method, result)
	if err != nil {
		return common.Address{}, err
	}
	if len(ret) != 1 {
		return common.Address{}, errors.New("invalid params length")
	}
	receiver, ok := ret[0].(common.Address)
	if !ok {
		return common.Address{}, errors.New("invalid validators format")
	}
	return receiver, nil
}

// get increase period
func (c *Congress) getIncreasePeriod(chain consensus.ChainHeaderReader, header *types.Header) (*big.Int, error) {
	parent := chain.GetHeader(header.ParentHash, header.Number.Uint64()-1)
	if parent == nil {
		return nil, consensus.ErrUnknownAncestor
	}
	statedb, err := c.stateFn(parent.Root)
	if err != nil {
		return nil, err
	}
	method := "increasePeriod"
	data, err := c.abi[proposalContractName].Pack(method)
	if err != nil {
		log.Error("Can't pack data for increasePeriod", "error", err)
		return nil, err
	}

	msg := newMessage(header.Coinbase, &proposalAddr, 0, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)

	// use parent
	result, err := executeMsg(msg, statedb, parent, newChainContext(chain, c), c.chainConfig)
	if err != nil {
		return nil, err
	}

	// unpack data
	ret, err := c.abi[proposalContractName].Unpack(method, result)
	if err != nil {
		return nil, err
	}
	if len(ret) != 1 {
		return nil, errors.New("invalid params length")
	}
	increasePeriod, ok := ret[0].(*big.Int)
	if !ok {
		return nil, errors.New("invalid increase period format")
	}
	return increasePeriod, nil
}

// call this at epoch block to get top validators based on the state of epoch block - 1
func (c *Congress) getTopValidators(chain consensus.ChainHeaderReader, header *types.Header) ([]common.Address, error) {
	parent := chain.GetHeader(header.ParentHash, header.Number.Uint64()-1)
	if parent == nil {
		return []common.Address{}, consensus.ErrUnknownAncestor
	}
	statedb, err := c.stateFn(parent.Root)
	if err != nil {
		return []common.Address{}, err
	}

	method := "getTopValidators"
	data, err := c.abi[validatorsContractName].Pack(method)
	if err != nil {
		log.Error("Can't pack data for getTopValidators", "error", err)
		return []common.Address{}, err
	}

	msg := newMessage(header.Coinbase, &validatorsContractAddr, 0, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)

	// use parent
	result, err := executeMsg(msg, statedb, parent, newChainContext(chain, c), c.chainConfig)
	if err != nil {
		return []common.Address{}, err
	}

	// unpack data
	ret, err := c.abi[validatorsContractName].Unpack(method, result)
	if err != nil {
		return []common.Address{}, err
	}
	if len(ret) != 1 {
		return []common.Address{}, errors.New("invalid params length")
	}
	validators, ok := ret[0].([]common.Address)
	if !ok {
		return []common.Address{}, errors.New("invalid validators format")
	}
	sort.Sort(validatorsAscending(validators))
	return validators, nil
}

func (c *Congress) updateValidators(vals []common.Address, chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	// For JPoSA: Use staking-based validator selection if staking contract is available
	if c.isJPoSAEnabled(header.Number) {
		return c.updateValidatorsByStake(chain, header, state)
	}

	// Original PoA method for backward compatibility
	method := "updateActiveValidatorSet"
	data, err := c.abi[validatorsContractName].Pack(method, vals, new(big.Int).SetUint64(c.config.Epoch))
	if err != nil {
		log.Error("Can't pack data for updateActiveValidatorSet", "error", err)
		return err
	}

	// call contract
	nonce := state.GetNonce(header.Coinbase)
	msg := newMessage(header.Coinbase, &validatorsContractAddr, nonce, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, true)
	if _, err := executeMsg(msg, state, header, newChainContext(chain, c), c.chainConfig); err != nil {
		log.Error("Can't update validators to contract", "err", err)
		return err
	}

	return nil
}

// updateValidatorsByStake updates validators based on staking (JPoSA)
func (c *Congress) updateValidatorsByStake(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	method := "updateValidatorSetByStake"
	data, err := c.abi[validatorsContractName].Pack(method, new(big.Int).SetUint64(c.config.Epoch))
	if err != nil {
		log.Error("Can't pack data for updateValidatorSetByStake", "error", err)
		return err
	}

	// call contract
	nonce := state.GetNonce(header.Coinbase)
	msg := newMessage(header.Coinbase, &validatorsContractAddr, nonce, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, true)
	if _, err := executeMsg(msg, state, header, newChainContext(chain, c), c.chainConfig); err != nil {
		log.Error("Can't update validators by stake", "err", err)
		return err
	}

	log.Info("Updated validators based on staking", "epoch", c.config.Epoch, "block", header.Number)
	return nil
}

// isJPoSAEnabled checks if JPoSA (staking) is enabled at given block number
func (c *Congress) isJPoSAEnabled(blockNumber *big.Int) bool {
	// TODO: Add activation block number for JPoSA
	// For now, always enable JPoSA if staking contract exists
	return true
}

func (c *Congress) punishValidator(val common.Address, chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	// method
	method := "punish"
	data, err := c.abi[punishContractName].Pack(method, val)
	if err != nil {
		log.Error("Can't pack data for punish", "error", err)
		return err
	}

	// call contract
	nonce := state.GetNonce(header.Coinbase)
	msg := newMessage(header.Coinbase, &punishContractAddr, nonce, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, false)
	if _, err := executeMsg(msg, state, header, newChainContext(chain, c), c.chainConfig); err != nil {
		log.Error("Can't punish validator", "err", err)
		return err
	}

	return nil
}

func (c *Congress) decreaseMissedBlocksCounter(chain consensus.ChainHeaderReader, header *types.Header, state *state.StateDB) error {
	// method
	method := "decreaseMissedBlocksCounter"
	data, err := c.abi[punishContractName].Pack(method, new(big.Int).SetUint64(c.config.Epoch))
	if err != nil {
		log.Error("Can't pack data for decreaseMissedBlocksCounter", "error", err)
		return err
	}

	// call contract
	nonce := state.GetNonce(header.Coinbase)
	msg := newMessage(header.Coinbase, &punishContractAddr, nonce, new(big.Int), systemContractGasLimit, new(big.Int), new(big.Int), new(big.Int), data, types.AccessList{}, true)
	if _, err := executeMsg(msg, state, header, newChainContext(chain, c), c.chainConfig); err != nil {
		log.Error("Can't decrease missed blocks counter for validator", "err", err)
		return err
	}

	return nil
}

// Authorize injects a private key into the consensus engine to mint new blocks
// with.
func (c *Congress) Authorize(validator common.Address, signFn ValidatorFn) {
	c.lock.Lock()
	defer c.lock.Unlock()

	c.validator = validator
	c.signFn = signFn
}

// Seal implements consensus.Engine, attempting to create a sealed block using
// the local signing credentials.
func (c *Congress) Seal(chain consensus.ChainHeaderReader, block *types.Block, results chan<- *types.Block, stop <-chan struct{}) error {
	header := block.Header()

	// Sealing the genesis block is not supported
	number := header.Number.Uint64()
	if number == 0 {
		return errUnknownBlock
	}
	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
	if c.config.Period == 0 && len(block.Transactions()) == 0 {
		log.Info("Sealing paused, waiting for transactions")
		return nil
	}
	// Don't hold the val fields for the entire sealing procedure
	c.lock.RLock()
	val, signFn := c.validator, c.signFn
	c.lock.RUnlock()

	// Bail out if we're unauthorized to sign a block
	snap, err := c.snapshot(chain, number-1, header.ParentHash, nil)
	if err != nil {
		return err
	}
	if _, authorized := snap.Validators[val]; !authorized {
		return errUnauthorizedValidator
	}
	// If we're amongst the recent validators, wait for the next block
	for seen, recent := range snap.Recents {
		if recent == val {
			// Validator is among recents, only wait if the current block doesn't shift it out
			if limit := uint64(len(snap.Validators)/2 + 1); number < limit || seen > number-limit {
				log.Info("Signed recently, must wait for others")
				return nil
			}
		}
	}

	// Sweet, the protocol permits us to sign the block, wait for our time
	delay := time.Until(time.Unix(int64(header.Time), 0))
	if header.Difficulty.Cmp(diffNoTurn) == 0 {
		// It's not our turn explicitly to sign, delay it a bit
		wiggle := time.Duration(len(snap.Validators)/2+1) * wiggleTime
		delay += time.Duration(rand.Int63n(int64(wiggle)))

		log.Trace("Out-of-turn signing requested", "wiggle", common.PrettyDuration(wiggle))
	}
	// Sign all the things!
	sighash, err := signFn(accounts.Account{Address: val}, accounts.MimetypeCongress, CongressRLP(header))
	if err != nil {
		return err
	}
	copy(header.Extra[len(header.Extra)-extraSeal:], sighash)
	// Wait until sealing is terminated or delay timeout.
	log.Trace("Waiting for slot to sign and propagate", "delay", common.PrettyDuration(delay))
	go func() {
		select {
		case <-stop:
			return
		case <-time.After(delay):
		}

		select {
		case results <- block.WithSeal(header):
		default:
			log.Warn("Sealing result is not read by miner", "sealhash", SealHash(header))
		}
	}()
	return nil
}

// CalcDifficulty is the difficulty adjustment algorithm. It returns the difficulty
// that a new block should have:
// * DIFF_NOTURN(2) if BLOCK_NUMBER % validator_COUNT != validator_INDEX
// * DIFF_INTURN(1) if BLOCK_NUMBER % validator_COUNT == validator_INDEX
func (c *Congress) CalcDifficulty(chain consensus.ChainHeaderReader, time uint64, parent *types.Header) *big.Int {
	snap, err := c.snapshot(chain, parent.Number.Uint64(), parent.Hash(), nil)
	if err != nil {
		return nil
	}
	return calcDifficulty(snap, c.validator)
}

func calcDifficulty(snap *Snapshot, validator common.Address) *big.Int {
	if snap.inturn(snap.Number+1, validator) {
		return new(big.Int).Set(diffInTurn)
	}
	return new(big.Int).Set(diffNoTurn)
}

// SealHash returns the hash of a block prior to it being sealed.
func (c *Congress) SealHash(header *types.Header) common.Hash {
	return SealHash(header)
}

// Close implements consensus.Engine. It's a noop for congress as there are no background threads.
func (c *Congress) Close() error {
	return nil
}

// APIs implements consensus.Engine, returning the user facing RPC API to allow
// controlling the validator voting.
func (c *Congress) APIs(chain consensus.ChainHeaderReader) []rpc.API {
	return []rpc.API{{
		Namespace: "congress",
		Version:   "1.0",
		Service:   &API{chain: chain, congress: c},
		Public:    false,
	}}
}

// SealHash returns the hash of a block prior to it being sealed.
func SealHash(header *types.Header) (hash common.Hash) {
	hasher := sha3.NewLegacyKeccak256()
	encodeSigHeader(hasher, header)
	hasher.Sum(hash[:0])
	return hash
}

// CongressRLP returns the rlp bytes which needs to be signed for the proof-of-stake-authority
// sealing. The RLP to sign consists of the entire header apart from the 65 byte signature
// contained at the end of the extra data.
//
// Note, the method requires the extra data to be at least 65 bytes, otherwise it
// panics. This is done to avoid accidentally using both forms (signature present
// or not), which could be abused to produce different hashes for the same header.
func CongressRLP(header *types.Header) []byte {
	b := new(bytes.Buffer)
	encodeSigHeader(b, header)
	return b.Bytes()
}

func encodeSigHeader(w io.Writer, header *types.Header) {
	enc := []interface{}{
		header.ParentHash,
		header.UncleHash,
		header.Coinbase,
		header.Root,
		header.TxHash,
		header.ReceiptHash,
		header.Bloom,
		header.Difficulty,
		header.Number,
		header.GasLimit,
		header.GasUsed,
		header.Time,
		header.Extra[:len(header.Extra)-crypto.SignatureLength], // Yes, this will panic if extra is too short
		header.MixDigest,
		header.Nonce,
	}

	// Add BaseFee for London fork and later
	if header.BaseFee != nil {
		enc = append(enc, header.BaseFee)
	}

	// Add WithdrawalsHash for Shanghai fork and later
	if header.WithdrawalsHash != nil {
		enc = append(enc, header.WithdrawalsHash)
	}

	// Add blob gas fields for Cancun fork and later
	if header.BlobGasUsed != nil {
		enc = append(enc, header.BlobGasUsed)
	}
	if header.ExcessBlobGas != nil {
		enc = append(enc, header.ExcessBlobGas)
	}

	// Add parent beacon root for Cancun fork and later
	if header.ParentBeaconRoot != nil {
		enc = append(enc, header.ParentBeaconRoot)
	}

	err := rlp.Encode(w, enc)
	if err != nil {
		panic("can't encode: " + err.Error())
	}
}

// newMessage is a new method that maintains compatibility with the removed types.NewMessage method
// In congress consensus, only from, to, data, gas, value are used
// The isFake parameter is not used in the original logic either
func newMessage(from common.Address, to *common.Address, nonce uint64, amount *big.Int, gasLimit uint64, gasPrice, gasFeeCap, gasTipCap *big.Int, data []byte, accessList types.AccessList, isFake bool) core.Message {
	return core.Message{
		From:       from,
		To:         to,
		Nonce:      nonce,
		Value:      amount,
		GasLimit:   gasLimit,
		GasPrice:   gasPrice,
		GasFeeCap:  gasFeeCap,
		GasTipCap:  gasTipCap,
		Data:       data,
		AccessList: accessList,
	}
}
