// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

// Interface for Circles Hub to check if an account is registered as a human
struct TrustMarker {
    address previous;
    uint96 expiry;
}

interface IHubV2 {
    function day(uint256 _timestamp) external view returns (uint64);
    function registerHuman(address _inviter, bytes32 _metadataDigest) external;
    function registerOrganization(string calldata _name, bytes32 _metadataDigest) external;
    function calculateIssuanceWithCheck(address _human) external returns (uint256, uint256, uint256);
    function trust(address _trustReceiver, uint96 _expiry) external;
    function migrate(address _owner, address[] calldata _avatars, uint256[] calldata _amounts) external;
    function isHuman(address _human) external view returns (bool);
    function isOrganization(address _organization) external view returns (bool);
    function isGroup(address _group) external view returns (bool);
    function avatars(address _avatar) external view returns (address);
    function balanceOf(address owner, uint256 id) external view returns (uint256);
    function toTokenId(address _avatar) external pure returns (uint256);
    function isTrusted(address _truster, address _trustee) external view returns (bool);
    function invitationOnlyTime() external view returns (uint256);
    function personalMint() external;
    function trustMarkers(address truster, address trustee) external view returns (TrustMarker calldata trustMarker);
}
