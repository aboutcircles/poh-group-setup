// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IProofOfHumanity {
    /**
     * @dev Emitted when humanity is successfully claimed.
     *  @param humanityId The humanity ID.
     *  @param requestId The ID of the successfull request.
     */
    event HumanityClaimed(bytes20 humanityId, uint256 requestId);

    /**
     * @dev Emitted when humanity is successfully revoked.
     *  @param humanityId The humanity ID.
     *  @param requestId The ID of the successfull request.
     */
    event HumanityRevoked(bytes20 humanityId, uint256 requestId);

    struct HumanityInfo {
        bool vouching;
        bool pendingRevocation;
        uint48 nbPendingRequests;
        uint40 expirationTime;
        address owner;
        uint256 nbRequests;
    }

    /* Views */

    function isHuman(address _address) external view returns (bool);

    function isClaimed(bytes20 _humanityId) external view returns (bool);

    function boundTo(bytes20 _humanityId) external view returns (address);

    function humanityOf(address _account) external view returns (bytes20 humanityId);

    function getHumanityInfo(bytes20 _humanityId)
        external
        view
        returns (
            bool vouching,
            bool pendingRevocation,
            uint48 nbPendingRequests,
            uint40 expirationTime,
            address owner,
            uint256 nbRequests
        );

    function getHumanityCount() external view returns (uint256);
}
