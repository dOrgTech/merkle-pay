// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/*
    Cumulative Merkle distributor
*/
interface ICumulativeMultiTokenMerkleDistributor {
    event RootPublished(
        uint256 indexed cycle,
        bytes32 indexed root,
        bytes32 indexed contentHash,
        uint256 blockTimestamp,
        uint256 blockNumber
    );
    event Claimed(
        address indexed user,
        address indexed token,
        uint256 indexed cycle,
        uint256 amount
    );
}
