// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Nudix} from "src/Nudix.sol";

contract NudixTest is Test {
    Nudix token;
    address recipient;
    uint256 recipientKey;
    address user = address(0xB0B);

    uint256 initialSupply = 1_000_000_000 * 10 ** 18;

    function setUp() external {
        (recipient, recipientKey) = makeAddrAndKey("recipient");

        // Deploy the token contract
        token = new Nudix(recipient);

    }

    function test_initialSupplyAssignedToRecipient() external view {
        // Assert that the initial supply is minted to the recipient
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(recipient), initialSupply);
    }

    function test_transfer() external {
        uint256 transferAmount = 1000 * 10 ** 18;

        // Prank as the recipient to transfer tokens
        vm.prank(recipient);
        bool success = token.transfer(user, transferAmount);
        assertTrue(success);

        // Assertions
        assertEq(token.balanceOf(user), transferAmount);
        assertEq(token.balanceOf(recipient), initialSupply - transferAmount);
    }

    function test_transfer_revertIfInsufficientBalance() external {
        uint256 transferAmount = 1000 * 10 ** 18;

        // Expect revert with custom error
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")), user, 0, transferAmount
            )
        );

        vm.prank(user);
        bool success = token.transfer(recipient, transferAmount);
        assertFalse(success);
    }

    function test_burn(uint256 tokenAmount) external {
        vm.assume(tokenAmount < initialSupply);

        vm.prank(recipient);
        token.burn(tokenAmount);

        // Assertions
        assertEq(token.balanceOf(recipient), initialSupply - tokenAmount);
        assertEq(token.totalSupply(), initialSupply - tokenAmount);
    }

    function test_burnFrom(uint256 tokenAmount) external {
        vm.assume(tokenAmount < initialSupply);

        address sender = makeAddr("sender");

        vm.prank(recipient);
        token.approve(sender, type(uint256).max);

        vm.prank(sender);
        token.burnFrom(recipient, tokenAmount);

        // Assertions
        assertEq(token.balanceOf(recipient), initialSupply - tokenAmount);
        assertEq(token.totalSupply(), initialSupply - tokenAmount);
    }

    function test_permit(uint256 tokenAmount) public {
        vm.assume(tokenAmount < initialSupply);

        address sender = makeAddr("sender");
        uint256 deadline = block.timestamp + 1 days;
        uint8 v;
        bytes32 r;
        bytes32 s;

        // Check initial nonce is 0
        assertEq(token.nonces(recipient), 0);

        // Create permit signature
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = 0;
        bytes32 structHash = keccak256(abi.encode(permitTypehash, recipient, sender, tokenAmount, nonce, deadline));
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Sign the permit with recipient's private key
        (v, r, s) = vm.sign(recipientKey, digest);

        // Submit the permit
        token.permit(recipient, sender, tokenAmount, deadline, v, r, s);

        // Verify nonce increased and allowance set
        assertEq(token.nonces(recipient), 1);
        assertEq(token.allowance(recipient, sender), tokenAmount);

        // Transfer tokens using the permit
        vm.prank(sender);
        bool success = token.transferFrom(recipient, sender, tokenAmount);
        assertTrue(success);

        // Verify balances after transfer
        assertEq(token.balanceOf(recipient), initialSupply - tokenAmount);
        assertEq(token.balanceOf(sender), tokenAmount);
    }
}
