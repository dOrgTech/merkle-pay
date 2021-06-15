pragma solidity ^0.7.6;

library MerkleTree {
    /**
     * @dev Verifies a Merkle proof proving the existence of a leaf in a Merkle tree. Assumes that each pair of leaves
     * and each pair of pre-images are sorted.
     * @param proof Merkle proof containing sibling hashes on the branch from the leaf to the root of the Merkle tree
     * @param root Merkle root
     * @param leaf Leaf of Merkle tree
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        // Check if the computed hash (root) is equal to the provided root
        return computeRoot(proof, leaf) == root;
    }

    function computeRoot(bytes32[] memory proof, bytes32 leaf)
        internal
        pure
        returns (bytes32)
    {
        bytes32 node = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 pairNode = proof[i];

            if (pairNode < node) {
                // Hash(current element of the proof + current computed hash)
                node = hashBranch(pairNode, node);
            } else {
                // Hash(current computed hash + current element of the proof)
                node = hashBranch(node, pairNode);
            }
        }

        return node;
    }

    // function hashLeaf(bytes32 leaf) internal pure returns (bytes32) {
    //     bytes1 LEAF_PREFIX = 0x00;
    //     return keccak256(abi.encodePacked(LEAF_PREFIX, leaf));
    // }

    function hashBranch(bytes32 left, bytes32 right)
        internal
        pure
        returns (bytes32)
    {
        bytes1 BRANCH_PREFIX = 0x01;
        return keccak256(abi.encodePacked(BRANCH_PREFIX, left, right));
    }
}
