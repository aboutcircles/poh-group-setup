// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

import {IBaseGroup} from "src/interfaces/IBaseGroup.sol";
import {PoHMembershipCondition} from "src/PoHMembershipCondition.sol";

/**
 * @title PoHGroupService
 * @notice Service contract for managing Proof of Humanity (PoH) based group memberships in Circles
 * @dev This contract acts as a bridge between PoH verification and Circles group trust management.
 *      It ensures that only verified human accounts with valid PoH credentials can be trusted
 *      in the associated Circles group, with trust expiration aligned to PoH expiration.
 */
contract PoHGroupService {
    error HumanityIdDoesNotMatch(bytes20 submittedId, bytes20 registeredId);
    error InvalidPoHId();
    error InvalidAccount(address account);

    IBaseGroup public immutable group;
    PoHMembershipCondition public immutable pohMembershipCondition;

    /**
     * @notice Initializes the PoH Group Service with required contracts
     * @param _group Address of the Circles group contract to manage
     * @param _pohMembershipCondition Address of the PoH membership condition contract
     * @dev Sets the deployer as the initial owner who can register members
     */
    constructor(address _group, address _pohMembershipCondition) {
        group = IBaseGroup(_group);
        pohMembershipCondition = PoHMembershipCondition(_pohMembershipCondition);
    }

    /**
     * @notice Manages group membership for an account based on PoH verification status
     * @param humanityID The humanity ID of the account to manage
     * @param _account Address of the circles account to manage in PoH group
     * @dev This function performs comprehensive membership management:
     *      1. Registers the account with PoH if not already registered
     *      2. Verifies the humanity ID matches the registered one
     *      3. Checks PoH ID expiration status and acts accordingly:
     *         - If valid: Trusts/updates trust with new expiration time
     *         - If expired: Will revert with InvalidPoHId (effectively untrusting)
     *      4. Updates group trust expiration to match current PoH expiration
     * @dev This function can be used for multiple purposes:
     *      - Initial registration and trust establishment
     *      - Trust expiration updates when PoH credentials are renewed
     *      - Implicit untrusting when PoH credentials have expired
     */
    function register(bytes20 humanityID, address _account) external {
        if (!pohMembershipCondition.isRegistered(_account)) {
            pohMembershipCondition.registerMemberWithPoHId(_account, humanityID);
        }
        bytes20 pohId = pohMembershipCondition.circlesToPoH(_account);
        if (humanityID != pohId) revert HumanityIdDoesNotMatch(humanityID, pohId);

        uint40 expirationTime = pohMembershipCondition.getPoHIdExpirationTime(pohId);

        if (expirationTime <= uint40(block.timestamp)) revert InvalidPoHId();

        _trustAccount(_account, uint96(expirationTime));
    }

    function untrust(address _account) external {
        if (!pohMembershipCondition.isRegistered(_account)) {
            revert InvalidAccount(_account);
        }
        bytes20 pohId = pohMembershipCondition.circlesToPoH(_account);

        if (!pohMembershipCondition.isPoHIdValid(pohId)) {
            // untrust account
            _trustAccount(_account, uint96(0));
        }
    }

    function untrustByPoHId(bytes20 _pohId) external {
        address account = pohMembershipCondition.PoHToCircles(_pohId);
        if (account == address(0)) revert InvalidPoHId();

        if (!pohMembershipCondition.isPoHIdValid(_pohId)) {
            // untrust account
            _trustAccount(account, uint96(0));
        }
    }

    function _trustAccount(address _account, uint96 _expiry) private {
        address[] memory singleMemberArray = new address[](1);
        singleMemberArray[0] = _account;

        group.trustBatchWithConditions(singleMemberArray, _expiry);
    }
}
