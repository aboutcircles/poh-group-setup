// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.28;

import {IMembershipCondition} from "src/interfaces/IMembershipCondition.sol";
import {IProofOfHumanity} from "src/interfaces/IProofOfHumanity.sol";
import {ICrossChainProofOfHumanity} from "src/interfaces/ICrossChainProofOfHumanity.sol";

import {CirclesLinkRegistry} from "@link-registry/src/CirclesLinkRegistry.sol";

/**
 * @title PoHMembershipCondition
 * @notice Membership condition that verifies Proof of Humanity status for Circles group eligibility
 * @dev This contract manages the association between Circles accounts and PoH IDs through a linking system.
 *      It supports both regular PoH and cross-chain PoH, ensuring that each PoH ID can only
 *      be linked to one Circles account to prevent sybil attacks.
 */
contract PoHMembershipCondition is IMembershipCondition {
    // Events
    event PoHIdHolderRegistered(address indexed circlesAccount, bytes20 indexed humanityId);

    // Errors
    error LinkIsNotEstablished(address circlesAccount, address externalAccount);
    error PoHIdIsAlreadyLinked(address circlesAccount, bytes20 humanityId);
    error ValidPoHIdNotFound(address account);

    // Constants
    uint256 constant MAX_LOOP_ITERATIONS = 50;
    address internal constant SENTINEL = address(0x1);

    // State Variables
    /// @notice Registry mapping Circles accounts to their associated PoH IDs
    /// @dev bytes20 is used for PoH humanity IDs, empty bytes20 indicates no registration
    mapping(address => bytes20) public circlesToPoH;
    mapping(bytes20 => address) public PoHToCircles;

    IProofOfHumanity public immutable proofOfHumanity;
    ICrossChainProofOfHumanity public immutable pohCrossChain;

    CirclesLinkRegistry public immutable linkRegistry;

    /**
     * @notice Constructor initializes the PoH and linking contracts
     * @param _proofOfHumanity Address of the Proof of Humanity contract
     * @param _pohCrossChain Address of the Proof of Humanity cross chain registry contract
     * @param _linkingContract Address of the Circles linking registry
     */
    constructor(address _proofOfHumanity, address _pohCrossChain, address _linkingContract) {
        proofOfHumanity = IProofOfHumanity(_proofOfHumanity);
        pohCrossChain = ICrossChainProofOfHumanity(_pohCrossChain);
        linkRegistry = CirclesLinkRegistry(_linkingContract);
    }

    /**
     * @notice Checks if an avatar passes the membership condition
     * @param avatar The Circles account to check
     * @return bool Whether the avatar has a valid PoH registration
     */
    function passesMembershipCondition(address avatar) external view returns (bool) {
        // Check if there is a linked PoH ID in registry
        if (isRegistered(avatar)) {
            // Returns true if the PoH ID is still valid
            return isPoHIdValid(circlesToPoH[avatar]);
        }

        return false;
    }

    /**
     * @notice Registers a member by linking a Circles account to a PoH account
     * @param circlesAccount The Circles account to register
     * @param pohIdAccount The account that holds the PoH ID
     */
    function registerMember(address circlesAccount, address pohIdAccount) external {
        if (!linkRegistry.isLinkEstablished(circlesAccount, pohIdAccount)) {
            revert LinkIsNotEstablished(circlesAccount, pohIdAccount);
        }
        if (!hasValidPoHId(pohIdAccount)) revert ValidPoHIdNotFound(pohIdAccount);

        _registerPoHId(circlesAccount, getPoHIdByOwner(pohIdAccount));
    }

    /**
     * @notice Registers a member by linking a Circles account to a PoH account
     * @param circlesAccount The Circles account to register
     * @param humanityID PoH ID that should be registered
     */
    function registerMemberWithPoHId(address circlesAccount, bytes20 humanityID) external {
        address pohIdAccount = getOwnerByPoHId(humanityID);

        if (!linkRegistry.isLinkEstablished(circlesAccount, pohIdAccount)) {
            revert LinkIsNotEstablished(circlesAccount, pohIdAccount);
        }
        // @dev this check is required to verify that the PoH ID is valid
        if (!hasValidPoHId(pohIdAccount)) revert ValidPoHIdNotFound(pohIdAccount);

        _registerPoHId(circlesAccount, humanityID);
    }

    /**
     * @notice Automatically registers a member by finding linked PoH accounts or checking if Cicles account has PoH ID
     * @param circlesAccount The Circles account to register
     */
    function registerMemberAuto(address circlesAccount) external {
        // First check if the Circles account itself has a valid PoH ID
        if (hasValidPoHId(circlesAccount)) {
            bytes20 pohId = getPoHIdByOwner(circlesAccount);

            _registerPoHId(circlesAccount, pohId);
        } else {
            // Search through linked accounts for one with valid PoH ID
            address current = linkRegistry.circlesToExternal(circlesAccount, SENTINEL);

            // Iterate over linked list
            for (uint256 i = 0; current != address(0) && current != SENTINEL && i < MAX_LOOP_ITERATIONS; i++) {
                // Check if there is a bidirectional link
                // Check if linked account has PoHId
                if (linkRegistry.isExternalLinkedTo(current, circlesAccount) && hasValidPoHId(current)) {
                    bytes20 pohId = getPoHIdByOwner(current);
                    _registerPoHId(circlesAccount, pohId);

                    break;
                }

                // Move to next element
                current = linkRegistry.circlesToExternal(circlesAccount, current);
            }
        }

        if (!isRegistered(circlesAccount)) revert ValidPoHIdNotFound(circlesAccount);
    }

    /**
     * @notice Checks if an account has a valid PoH ID
     * @param account The account to check
     * @return bool Whether the account has a valid PoH ID
     */
    function hasValidPoHId(address account) public view returns (bool) {
        return proofOfHumanity.isHuman(account) || pohCrossChain.isHuman(account);
    }

    /**
     * @notice Checks if a PoH ID is still valid (not expired)
     * @param pohId The PoH ID to check
     * @return bool Whether the PoH ID is still valid
     */
    function isPoHIdValid(bytes20 pohId) public view returns (bool) {
        uint40 expirationTime = getPoHIdExpirationTime(pohId);

        // Returns true if the PoH ID is still valid (not expired)
        return expirationTime >= uint40(block.timestamp);
    }

    /**
     * @notice Checks if a Circles account is registered with a PoH ID
     * @param _circlesAccount The Circles account to check
     * @return bool Whether the account is registered
     * @dev Returns false if the account has no associated PoH ID
     */
    function isRegistered(address _circlesAccount) public view returns (bool) {
        return circlesToPoH[_circlesAccount] != bytes20(0);
    }

    /**
     * @notice Checks if a PoH ID is already linked to a Circles account
     * @param _pohId The PoH ID to check
     * @return bool Whether the PoH ID is already in use
     * @dev Prevents double-spending of PoH credentials
     */
    function isPoHIdUsed(bytes20 _pohId) public view returns (bool) {
        return PoHToCircles[_pohId] != address(0);
    }

    /**
     * @notice Gets the expiration time of a PoH ID
     * @param pohId The PoH ID to check
     * @return expirationTime The timestamp when the PoH ID expires
     * @dev Retrieves expiration from the PoH contract's humanity info
     */
    function getPoHIdExpirationTime(bytes20 pohId) public view returns (uint40 expirationTime) {
        // @todo verify that this works correctly for regular PoH IDs and cross chain
        // Extract expiration time from PoH contract's humanity info
        // The function returns multiple values, we only need the expiration time (4th parameter)
        (,,, expirationTime,,) = proofOfHumanity.humanityData(pohId); // @todo we should better use humanity data
    }

    /**
     * @notice Gets the PoH ID associated with an account
     * @param _account The account to lookup
     * @return pohId The PoH ID owned by this account, or bytes20(0) if none
     * @dev Checks both regular PoH and cross-chain PoH contracts
     */
    function getPoHIdByOwner(address _account) public view returns (bytes20 pohId) {
        pohId = proofOfHumanity.humanityOf(_account);
        if (pohId == bytes20(0)) {
            pohId = pohCrossChain.humanityOf(_account);
        }
    }

    /**
     * @notice Gets the owner address of a PoH ID
     * @param _pohId The PoH ID to lookup
     * @return owner The address that owns this PoH ID, or address(0) if none
     * @dev Checks both regular PoH and cross-chain PoH contracts
     */
    function getOwnerByPoHId(bytes20 _pohId) public view returns (address owner) {
        owner = proofOfHumanity.boundTo(_pohId);
        if (owner == address(0)) {
            owner = pohCrossChain.boundTo(_pohId);
        }
    }

    // Internal functions

    /**
     * @notice Internal function to register a PoH ID for a Circles account
     * @param circlesAccount The Circles account to register
     * @param pohId The PoH ID to associate
     */
    function _registerPoHId(address circlesAccount, bytes20 pohId) private {
        if (isRegistered(circlesAccount)) {
            revert PoHIdIsAlreadyLinked(circlesAccount, circlesToPoH[circlesAccount]);
        }
        if (isPoHIdUsed(pohId)) {
            revert PoHIdIsAlreadyLinked(PoHToCircles[pohId], pohId);
        }

        circlesToPoH[circlesAccount] = pohId;
        PoHToCircles[pohId] = circlesAccount;

        emit PoHIdHolderRegistered(circlesAccount, pohId);
    }
}
