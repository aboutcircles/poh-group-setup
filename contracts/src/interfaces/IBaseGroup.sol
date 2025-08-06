// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.28;

interface IBaseGroup {
    function setService(address _service) external;
    function trustBatchWithConditions(address[] memory _members, uint96 _expiry) external;
}
