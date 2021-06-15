// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "./ICumulativeMultiTokenMerkleDistributor.sol";

contract MerklePay is Ownable, ICumulativeMultiTokenMerkleDistributor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    struct MerkleData {
        uint32 cycle;
        bytes32 root;
        bytes32 contentHash;
        uint32 blockTimestamp;
        uint32 blockNumber;
    }

    MerkleData public merkleData;

    mapping(address => mapping(address => uint256)) public claimed;
    mapping(address => uint256) public totalClaimed;

    // Mapping of historical merkle roots. Other information about each cycle such as content hash and start/end blocks are not used on-chain and can be found in historical events
    mapping(uint256 => bytes32) merkleRoots;

    constructor(address _owner) {
        transferOwnership(_owner);
    }

    function getMerkleRootFor(uint256 cycle) public view returns (bytes32) {
        return merkleRoots[cycle];
    }

    /// @dev Return true if account has outstanding claims in any token from the given input data
    function isClaimAvailableFor(
        address user,
        address[] memory tokens,
        uint256[] memory cumulativeAmounts
    ) public view returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 userClaimable = cumulativeAmounts[i].sub(
                claimed[user][tokens[i]]
            );
            if (userClaimable > 0) {
                return true;
            }
        }
        return false;
    }

    /// @dev Get the number of tokens claimable for an account, given a list of tokens and latest cumulativeAmounts data
    function getClaimableFor(
        address user,
        address[] memory tokens,
        uint256[] memory cumulativeAmounts
    ) public view returns (address[] memory, uint256[] memory) {
        uint256[] memory userClaimable = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            userClaimable[i] = cumulativeAmounts[i].sub(
                _getClaimed(user, tokens[i])
            );
        }
        return (tokens, userClaimable);
    }

    /// @dev Get the cumulative number of tokens claimed for an account, given a list of tokens
    function getClaimedFor(address user, address[] memory tokens)
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256[] memory userClaimed = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            userClaimed[i] = claimed[user][tokens[i]];
        }
        return (tokens, userClaimed);
    }

    /// @notice Claim specifiedrewards for a set of tokens at a given cycle number
    /// @notice Can choose to skip certain tokens by setting amount to claim to zero for that token index
    function claim(
        address[] calldata tokens,
        uint256[] calldata cumulativeAmounts,
        uint256 cycle,
        bytes32[] calldata merkleProof,
        uint256[] calldata amountsToClaim
    ) external {
        // require(cycle <= cycle, "Invalid cycle");
        require(cycle == cycle, "Invalid cycle");
        _verifyClaimProof(tokens, cumulativeAmounts, cycle, merkleProof);

        bool claimedAny = false; // User must claim at least 1 token by the end of the function

        // Claim each token
        for (uint256 i = 0; i < tokens.length; i++) {
            // Run claim and register claimedAny if a claim occurs
            if (
                _tryClaim(
                    msg.sender,
                    cycle,
                    tokens[i],
                    cumulativeAmounts[i],
                    amountsToClaim[i]
                )
            ) {
                claimedAny = true;
            }
        }

        // If no tokens were claimed, revert
        if (claimedAny == false) {
            revert("No tokens to claim");
        }
    }

    // ===== Root Updater Restricted =====

    /// @notice Publish a new root
    function publishRoot(
        uint32 cycle,
        bytes32 root,
        bytes32 contentHash,
        uint32 blockNumber,
        uint32 blockTimestamp
    ) external onlyOwner {
        require(merkleData.cycle > cycle, "Incorrect cycle");
        require(
            merkleData.blockTimestamp < blockTimestamp,
            "blockTimestamp older than last"
        );
        require(
            merkleData.blockTimestamp < blockTimestamp,
            "blockTimestamp older than last"
        );
        require(
            merkleData.blockNumber < blockNumber,
            "blockNumber older than last"
        );
        require(blockNumber < block.number - 30, "Block number too soon");
        require(
            blockTimestamp < block.timestamp - 30 * 13,
            "Timestamp too soon"
        );

        merkleData.cycle = cycle;
        merkleData.root = root;
        merkleData.contentHash = contentHash;
        merkleData.blockNumber = blockNumber;
        merkleData.blockTimestamp = blockTimestamp;

        emit RootPublished(
            cycle,
            root,
            contentHash,
            blockTimestamp,
            blockNumber
        );
    }

    /// ===== Internal Helper Functions =====

    function _verifyClaimProof(
        address[] calldata tokens,
        uint256[] calldata cumulativeAmounts,
        uint256 cycle,
        bytes32[] calldata merkleProof
    ) internal view {
        // Verify the merkle proof.
        bytes32 node = keccak256(
            abi.encode(msg.sender, cycle, tokens, cumulativeAmounts)
        );
        require(
            MerkleProof.verify(merkleProof, merkleData.root, node),
            "Invalid proof"
        );
    }

    function _getClaimed(address account, address token)
        internal
        view
        returns (uint256)
    {
        return claimed[account][token];
    }

    function _setClaimed(
        address account,
        address token,
        uint256 amount
    ) internal {
        claimed[account][token] = amount;
    }

    function _tryClaim(
        address account,
        uint256 cycle,
        address token,
        uint256 cumulativeClaimable,
        uint256 toClaim
    ) internal returns (bool claimAttempted) {
        uint256 claimedBefore = _getClaimed(account, token);
        uint256 claimable = cumulativeClaimable.sub(claimedBefore);

        require(toClaim <= claimable, "Excessive claim");

        // If none claimable, don't attempt to claim
        if (claimable == 0) {
            return false;
        }

        uint256 claimedAfter = claimedBefore.add(toClaim);
        _setClaimed(account, token, claimedAfter);

        require(
            claimedAfter <= cumulativeClaimable,
            "Invariant: cumulative claimed > cumulative claimable"
        );
        IERC20(token).safeTransfer(account, toClaim);

        emit Claimed(account, token, cycle, toClaim);
        return true;
    }
}
