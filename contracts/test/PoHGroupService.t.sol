// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {CirclesLinkRegistry} from "@link-registry/src/CirclesLinkRegistry.sol";
import {PoHMembershipCondition} from "src/PoHMembershipCondition.sol";
import {PoHGroupService} from "src/PoHGroupService.sol";

import {IHubV2} from "src/interfaces/IHubV2.sol";
import {IProofOfHumanity} from "src/interfaces/IProofOfHumanity.sol";
import {IBaseGroupFactory} from "src/interfaces/IBaseGroupFactory.sol";
import {IBaseGroup} from "src/interfaces/IBaseGroup.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// @todo remove redunduncies
// @todo update test
contract CirclesLinkRegistryTest is Test {
    // Gnosis fork ID
    uint256 internal gnosisFork;

    CirclesLinkRegistry public circlesLinkRegistry;
    IHubV2 public HUB_V2;
    PoHMembershipCondition public membershipCondition;
    IBaseGroupFactory public baseGroupFactory;

    // Storage slots in the Hub
    uint256 public constant ORDER_FILLED_SLOT = 2;
    uint256 public constant DISCOUNTED_BALANCES_SLOT = 17;
    uint256 public constant MINT_TIMES_SLOT = 21;

    address public owner = address(0x1);
    address public circlesAccount1 = makeAddr("alice");
    address public circlesAccount2 = makeAddr("bob");
    address public externalAccount1 = makeAddr("alice-ext");
    address public externalAccount2 = makeAddr("bob-ext");

    // For signature testing
    uint256 public circlesPrivateKey = 0x1234;
    uint256 public externalPrivateKey = 0x5678;
    address public circlesSignerAccount;
    address public externalSignerAccount;

    // EIP-712 Domain and type constants
    bytes32 private constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant LINK_REQUEST_TYPEHASH = keccak256("LinkRequest(address from,address to,uint256 nonce)");

    //////
    address public HUB_V2_ADDRESS = 0xc12C1E50ABB450d6205Ea2C3Fa861b3B834d13e8;

    address constant ADMIN = address(0x1);
    address constant INVITER = address(0x5);

    // Constants for Linked List
    address constant SENTINEL = address(0x1);

    // Test constants
    uint256 constant DAY = 24 * 60 * 60;
    uint256 constant MONTH = 30 * DAY;
    uint256 constant YEAR = 365 * DAY;

    function setUp() public {
        // Fork from Gnosis
        gnosisFork = vm.createFork(vm.envString("GNOSIS_RPC"));
        vm.selectFork(gnosisFork);

        // Deploy the CirclesLinkRegistry with the owner account
        vm.startPrank(owner);
        // @todo move to consts
        baseGroupFactory = IBaseGroupFactory(0xD0B5Bd9962197BEaC4cbA24244ec3587f19Bd06d);
        circlesLinkRegistry = new CirclesLinkRegistry();
        membershipCondition = new PoHMembershipCondition(
            address(0xa4AC94C4fa65Bb352eFa30e3408e64F72aC857bc), // PoH registry address
            address(0x16044E1063C08670f8653055A786b7CC2034d2b0),
            address(circlesLinkRegistry)
        );
        vm.stopPrank();

        // Initialize contracts from existing addresses
        HUB_V2 = circlesLinkRegistry.HUB_V2();

        // Set up accounts for signature testing
        circlesSignerAccount = vm.addr(circlesPrivateKey);
        externalSignerAccount = vm.addr(externalPrivateKey);

        // Register test accounts as "human" in the Hub
        vm.prank(circlesAccount1);
        HUB_V2.registerOrganization("test org", bytes32(0x0));

        // Set up test accounts
        vm.deal(ADMIN, 100 ether);
        vm.deal(INVITER, 1000 ether);
        vm.deal(circlesAccount1, 100 ether);
        vm.deal(circlesAccount2, 100 ether);
        vm.deal(externalAccount1, 100 ether);
        vm.deal(externalAccount2, 100 ether);
    }

    function testBidirectionalLink() public {
        // Test link initiated by circles user, with signature from external user

        vm.prank(circlesAccount1);
        circlesLinkRegistry.link(externalAccount1);

        vm.prank(externalAccount1);
        circlesLinkRegistry.link(circlesAccount1);

        // Verify the link was established
        assertTrue(
            circlesLinkRegistry.isCirclesLinkedTo(circlesAccount1, externalAccount1),
            "CirclesUser1 should be linked to ExternalUser1"
        );
        assertTrue(
            circlesLinkRegistry.isExternalLinkedTo(externalAccount1, circlesAccount1),
            "ExternalUser1 should be linked to CirclesUser1"
        );
        assertTrue(
            circlesLinkRegistry.isLinkEstablished(circlesAccount1, externalAccount1), "Link should be established"
        );
    }

    function testGroupMembershipCondition() public {
        // Setup Service, Group and membership condition
        address[] memory testGroupMC = new address[](1);
        testGroupMC[0] = address(membershipCondition);

        (address group,,) =
            baseGroupFactory.createBaseGroup(owner, address(0x1), owner, testGroupMC, "TestGroup", "TG", bytes32(0));

        PoHGroupService service = new PoHGroupService(group, address(membershipCondition));
        // update service
        vm.prank(owner);
        IBaseGroup(group).setService(address(service));

        // Link two circles accounts
        // Link 1 account
        vm.prank(circlesAccount1);
        circlesLinkRegistry.link(externalAccount1);

        vm.prank(externalAccount1);
        circlesLinkRegistry.link(circlesAccount1);

        // Link 2 account
        // Account has PoHId
        externalAccount2 = address(0xb950Fc51a4f5fb19B06D282cC98cFe762820DA13);

        vm.prank(circlesAccount1);
        circlesLinkRegistry.link(externalAccount2);

        vm.prank(externalAccount2);
        circlesLinkRegistry.link(circlesAccount1);

        assertFalse(
            membershipCondition.passesMembershipCondition(circlesAccount1), "Membership condition before registration"
        );

        // Register/add user to the group
        // @notice !!!IMPORTANT!!! in this example PoH id matches the address which has it, but it is not always the case
        service.register(bytes20(0xb950Fc51a4f5fb19B06D282cC98cFe762820DA13), circlesAccount1);

        assertTrue(
            membershipCondition.passesMembershipCondition(circlesAccount1),
            "Membership condition state after registration"
        );
        assertTrue(HUB_V2.isTrusted(group, circlesAccount1), "Group trusts the member");
        assertEq(
            uint40(HUB_V2.trustMarkers(group, circlesAccount1).expiry),
            membershipCondition.getPoHIdExpirationTime(bytes20(0xb950Fc51a4f5fb19B06D282cC98cFe762820DA13)),
            "The group trust expiration time matches the PoH ID expiration"
        );
    }
}
