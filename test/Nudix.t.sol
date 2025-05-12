// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Nudix} from "src/Nudix.sol";

contract NudixTest is Test {
    Nudix token;
    address recipient = address(0xA11CE);
    address user = address(0xB0B);

    uint256 initialSupply = 1_000_000_000 * 10 ** 18;

    function setUp() public {
        // Deploy the token contract
        token = new Nudix(recipient);
    }

    function test_initialSupplyAssignedToRecipient() public view {
        // Assert that the initial supply is minted to the recipient
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(recipient), initialSupply);
    }

    function test_transfer() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        // Prank as the recipient to transfer tokens
        vm.prank(recipient);
        token.transfer(user, transferAmount);

        // Assertions
        assertEq(token.balanceOf(user), transferAmount);
        assertEq(token.balanceOf(recipient), initialSupply - transferAmount);
    }

    function test_transfer_revertIfInsufficientBalance() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        // Expect revert with custom error
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")),
                user,
                0,
                transferAmount
            )
        );
        token.transfer(recipient, transferAmount);
    }
}