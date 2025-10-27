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
	// TODO: Add the blackUser
	// common.HexToAddress("0xa485f86cf54bfd0ea351987c1a0b3c27218336d1"),
}

// InBlacklistV1 check wether from/to is in blacklist v1 or not
func InBlacklistV1(from, to common.Address) bool {
	return inBlacklist(from, to, BlacklistV1Addresses)
}

func inBlacklist(from, to common.Address, blacklist []common.Address) bool {
	for _, addr := range blacklist {
		if addr == from || addr == to {
			return true
		}
	}
	return false
}
