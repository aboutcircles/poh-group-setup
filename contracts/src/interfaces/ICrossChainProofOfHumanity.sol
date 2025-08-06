// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ICrossChainProofOfHumanity {
    // View functions (same as main interface)
    function isHuman(address _account) external view returns (bool);
    function isClaimed(bytes20 _humanityId) external view returns (bool);
    function boundTo(bytes20 _humanityId) external view returns (address);
    function humanityOf(address _account) external view returns (bytes20);
}
