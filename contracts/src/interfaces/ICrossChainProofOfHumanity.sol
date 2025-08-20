// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ICrossChainProofOfHumanity {
    /**
     * @dev Structure to store cross-chain humanity data.
     */
    struct CrossChainHumanity {
        address owner; // The owner address.
        uint40 expirationTime; // Expiration time at the moment of update.
        uint40 lastTransferTime; // Time of the last received transfer.
        bool isHomeChain; // Whether current chain is considered as home chain by this contract.
    }

    /**
     * @dev Returns the data for a specific humanity ID.
     * @param humanityId The ID of the humanity to query.
     * @return The humanity data.
     */
    function humanityData(bytes20 humanityId) external view returns (CrossChainHumanity memory);

    // View functions (same as main interface)
    function isHuman(address _account) external view returns (bool);
    function isClaimed(bytes20 _humanityId) external view returns (bool);
    function boundTo(bytes20 _humanityId) external view returns (address);
    function humanityOf(address _account) external view returns (bytes20);
}
