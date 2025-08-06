// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.28;

interface IBaseGroupFactory {
    function createBaseGroup(
        address _owner,
        address _service,
        address _feeCollection,
        address[] memory _initialConditions,
        string memory _name,
        string memory _symbol,
        bytes32 _metadataDigest
    ) external returns (address group, address mintHandler, address treasury);
    function deployedByFactory(address group) external view returns (bool deployed);
}
