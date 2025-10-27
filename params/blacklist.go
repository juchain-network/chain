// Copyright 2015 The go-ethereum Authors
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

package params

import (
	"github.com/ethereum/go-ethereum/common"
)

var BlacklistV1Addresses = []common.Address{
	// TODO: Add the blackUser here
	// common.HexToAddress("0xa485f86cf54bfd0ea351987c1a0b3c27218336d1"),
}

// internal set for O(1) membership checks, initialized from BlacklistV1Addresses
var blacklistV1Set map[common.Address]struct{}

func init() {
	// Build the set once from the slice to keep external API stable
	blacklistV1Set = make(map[common.Address]struct{}, len(BlacklistV1Addresses))
	for _, addr := range BlacklistV1Addresses {
		blacklistV1Set[addr] = struct{}{}
	}
}

// InBlacklistV1 checks whether from/to is in blacklist v1 or not
func InBlacklistV1(from, to common.Address) bool {
	return inBlacklistSet(from, to, blacklistV1Set)
}

func inBlacklistSet(from, to common.Address, set map[common.Address]struct{}) bool {
	if _, ok := set[from]; ok {
		return true
	}
	if _, ok := set[to]; ok {
		return true
	}
	return false
}
