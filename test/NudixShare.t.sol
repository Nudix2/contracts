// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {NudixShare} from "src/NudixShare.sol";

contract NudixShareTest is Test {
    NudixShare token;

    uint256 constant VALUE = 100e18;

    address admin;
    address minter;
    address hacker;
    address user2;
    address user;
    uint256 userPrivateKey;

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        hacker = makeAddr("hacker");
        user2 = makeAddr("user2");
        (user, userPrivateKey) = makeAddrAndKey("user");

        // Deploy the token contract
        token = new NudixShare(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    // region - Deploy -

    function test_deploy() public view {
        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(token.hasRole(token.MINTER_ROLE(), minter), true);

        assertEq(token.name(), "Nudix Share");
        assertEq(token.symbol(), "NUDIX-S");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    // endregion

    // region - Mint -

    function test_mint_revertIfNotMinterRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                hacker,
                token.MINTER_ROLE()
            )
        );

        vm.prank(hacker);
        token.mint(user, VALUE);
    }

    function test_mint_success() public {
        vm.prank(minter);
        token.mint(user, VALUE);

        assertEq(token.balanceOf(user), VALUE);
        assertEq(token.totalSupply(), VALUE);
    }

    // endregion

    // region - MintBatch -

    function test_mintBatch_revertIfNotMinterRole() public {
        address[] memory recipients = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                hacker,
                token.MINTER_ROLE()
            )
        );

        vm.prank(hacker);
        token.mintBatch(recipients, amounts);
    }

    function test_mintBatch_revertIfArrayLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = VALUE;

        vm.expectRevert(NudixShare.ArrayLengthMismatch.selector);

        vm.prank(minter);
        token.mintBatch(recipients, amounts);
    }

    function test_mintBatch_success() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = VALUE;
        amounts[1] = VALUE * 2;

        vm.prank(minter);
        token.mintBatch(recipients, amounts);

        assertEq(token.balanceOf(user), VALUE);
        assertEq(token.balanceOf(user2), VALUE * 2);
        assertEq(token.totalSupply(), VALUE * 3);
    }

    // endregion

    // region - Whitelist logic -

    //      region - addToWhitelist

    function test_addToWhitelist_revertIfAlreadyWhitelisted() public {
        vm.prank(admin);
        token.addToWhitelist(user);

        vm.expectRevert(abi.encodeWithSelector(NudixShare.AlreadyWhitelisted.selector, user));

        vm.prank(admin);
        token.addToWhitelist(user);
    }

    function test_addToWhitelist_revertIfNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                token.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(user);
        token.addToWhitelist(user2);
    }

    function test_addToWhitelist_emitWhitelisted() public {
        vm.expectEmit(true, false, false, false);
        emit NudixShare.Whitelisted(user);

        vm.prank(admin);
        token.addToWhitelist(user);
    }

    function test_addToWhitelist_success() public {
        assertFalse(token.isWhitelisted(user));

        vm.prank(admin);
        token.addToWhitelist(user);

        assertTrue(token.isWhitelisted(user));
    }

    // endregion

    //      region - removeFromWhitelist

    function test_removeFromWhitelist_revertIfNotWhitelisted() public {
        vm.expectRevert(abi.encodeWithSelector(NudixShare.NotWhitelisted.selector, user));

        vm.prank(admin);
        token.removeFromWhitelist(user);
    }

    function test_removeFromWhitelist_revertIfNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                token.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(user);
        token.removeFromWhitelist(user2);
    }

    function test_removeFromWhitelist_emitUnwhitelisted() public {
        vm.prank(admin);
        token.addToWhitelist(user);

        vm.expectEmit(true, false, false, false);
        emit NudixShare.Unwhitelisted(user);

        vm.prank(admin);
        token.removeFromWhitelist(user);
    }

    function test_removeFromWhitelist_success() public {
        vm.prank(admin);
        token.addToWhitelist(user);
        assertTrue(token.isWhitelisted(user));

        vm.prank(admin);
        token.removeFromWhitelist(user);
        assertFalse(token.isWhitelisted(user));
    }

    // endregion

    //      region - isWhitelisted

    function test_isWhitelisted_success() public {
        assertFalse(token.isWhitelisted(user));

        vm.prank(admin);
        token.addToWhitelist(user);
        assertTrue(token.isWhitelisted(user));

        vm.prank(admin);
        token.removeFromWhitelist(user);
        assertFalse(token.isWhitelisted(user));
    }

    // endregion

    //      region - update

    function test_update_revertIfRecipientNonWhitelisted() public {
        vm.prank(minter);
        token.mint(user, VALUE);

        vm.expectRevert(abi.encodeWithSelector(NudixShare.TransferProhibited.selector, user2));

        vm.prank(user);
        token.transfer(user2, VALUE);
    }

    function test_update_successIfRecipientWhitelisted() public {
        vm.prank(minter);
        token.mint(user, VALUE);

        vm.prank(admin);
        token.addToWhitelist(user2);

        vm.prank(user);
        token.transfer(user2, VALUE);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(user2), VALUE);
    }

    function test_update_successIfMint() public {
        vm.prank(minter);
        token.mint(user, VALUE);

        assertEq(token.balanceOf(user), VALUE);
    }

    function test_update_successIfBurn() public {
        vm.prank(minter);
        token.mint(user, VALUE);

        vm.prank(user);
        token.burn(VALUE);

        assertEq(token.balanceOf(user), 0);
    }

    // endregion

    // endregion

    // region - Permit -

    function test_permit() public {
        uint256 deadline = block.timestamp + 1 days;
        uint8 v;
        bytes32 r;
        bytes32 s;

        // Check initial nonce is 0
        assertEq(token.nonces(user), 0);

        // Mint tokens to user
        vm.prank(minter);
        token.mint(user, VALUE);

        // Add user2 to whitelist so they can receive tokens
        vm.prank(admin);
        token.addToWhitelist(user2);

        // Create permit signature
        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        uint256 nonce = 0;
        bytes32 structHash =
            keccak256(abi.encode(permitTypehash, user, user2, VALUE, nonce, deadline));
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        // Sign the permit with user's private key
        (v, r, s) = vm.sign(userPrivateKey, digest);

        // Submit the permit
        token.permit(user, user2, VALUE, deadline, v, r, s);

        // Verify nonce increased and allowance set
        assertEq(token.nonces(user), 1);
        assertEq(token.allowance(user, user2), VALUE);

        // Transfer tokens using the permit
        vm.prank(user2);
        token.transferFrom(user, user2, VALUE);

        // Verify balances after transfer
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(user2), VALUE);
    }

    function test_permit_revertIfExpired() public {
        uint256 deadline = block.timestamp;
        uint256 value = 100e18;
        uint8 v;
        bytes32 r;
        bytes32 s;

        uint256 currentNonce = token.nonces(user);

        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        bytes32 structHash =
            keccak256(abi.encode(permitTypehash, user, user2, value, currentNonce, deadline));
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        (v, r, s) = vm.sign(userPrivateKey, digest);

        // Fast forward time
        vm.warp(block.timestamp + 1);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, deadline)
        );
        token.permit(user, user2, value, deadline, v, r, s);

        // Check that nonce has not changed
        assertEq(token.nonces(user), currentNonce);
    }

    function test_permit_revertIfInvalidNonce() public {
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100e18;
        uint8 v;
        bytes32 r;
        bytes32 s;

        // Use an invalid nonce (1 instead of 0)
        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        bytes32 structHash = keccak256(abi.encode(permitTypehash, user, user2, value, 1, deadline));
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        (v, r, s) = vm.sign(userPrivateKey, digest);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Permit.ERC2612InvalidSigner.selector,
                0xA1B61083dc8ccF95FfFc381243E93a39FA49e58f,
                user
            )
        );
        token.permit(user, user2, value, deadline, v, r, s);
    }

    function test_permit_revertIfInvalidSignature() public {
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100e18;
        uint8 v = 27;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        uint256 currentNonce = token.nonces(user);

        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
        token.permit(user, user2, value, deadline, v, r, s);

        assertEq(token.nonces(user), currentNonce);
    }

    // endregion
}
