// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {INudixSale, Sale} from "src/interfaces/INudixSale.sol";
import {NudixSale} from "src/NudixSale.sol";
import {TemporaryNudix} from "src/TemporaryNudix.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract NudixSaleTest is Test {
    ERC20Mock paymentToken;
    TemporaryNudix shareToken;
    NudixSale sale;

    uint256 constant VALUE = 100e18;
    uint256 constant MIN_PURCHASE = 1e18;
    uint256 constant ROUND_RATE = 1e18;
    uint256 constant ROUND_CAP = 100_000e18;

    address owner;
    address wallet;
    address hacker;
    address user;

    function setUp() public {
        owner = makeAddr("owner");
        wallet = makeAddr("wallet");
        hacker = makeAddr("hacker");
        user = makeAddr("user");

        shareToken = new TemporaryNudix(owner);
        paymentToken = new ERC20Mock(18);

        sale = new NudixSale(address(shareToken), address(paymentToken), wallet, owner);

        vm.startPrank(owner);
        shareToken.grantRole(shareToken.MINTER_ROLE(), address(sale));
        vm.stopPrank();
    }

    // region - Deploy -

    function test_deploy_revertIfZeroAddress() public {
        // First case: shareToken == address(0)
        vm.expectRevert(abi.encodeWithSelector(INudixSale.ZeroAddress.selector));
        sale = new NudixSale(address(0), address(paymentToken), wallet, owner);

        // Second case: paymentToken == address(0)
        vm.expectRevert(abi.encodeWithSelector(INudixSale.ZeroAddress.selector));
        sale = new NudixSale(address(shareToken), address(0), wallet, owner);

        // Third case: wallet == address(0)
        vm.expectRevert(abi.encodeWithSelector(INudixSale.ZeroAddress.selector));
        sale = new NudixSale(address(shareToken), address(paymentToken), address(0), owner);
    }

    function test_deploy_success() public view {
        assertEq(sale.getWallet(), wallet);
        assertEq(sale.getTemporaryNudix(), address(shareToken));
        assertEq(sale.getPaymentToken(), address(paymentToken));
        assertEq(sale.getCurrentSaleId(), 0);
        assertEq(sale.owner(), owner);

        assertEq(paymentToken.decimals(), 18);
    }

    // endregion

    // region - Start sale -

    function test_startSale_revertIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));

        vm.prank(hacker);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
    }

    function test_startSale_revertIfCurrentSaleIsActive() public {
        vm.startPrank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.expectRevert(INudixSale.CurrentSaleMustNotBeActive.selector);

        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
        vm.stopPrank();
    }

    function test_startSale_revertIfIncorrectStartTime() public {
        vm.expectRevert(INudixSale.IncorrectStartTime.selector);

        vm.warp(block.timestamp + 1);

        vm.prank(owner);
        sale.startSale(block.timestamp - 1, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
    }

    function test_startSale_revertIfZeroParam() public {
        vm.startPrank(owner);

        // First case: roundRate == 0
        uint256 roundRate = 0;
        vm.expectRevert(abi.encodeWithSelector(INudixSale.ZeroParam.selector));
        sale.startSale(block.timestamp, MIN_PURCHASE, roundRate, ROUND_CAP);

        // Second case: roundCap == 0
        uint256 roundCap = 0;
        vm.expectRevert(abi.encodeWithSelector(INudixSale.ZeroParam.selector));
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, roundCap);

        vm.stopPrank();
    }

    function test_startSale_revertIfBelowMinPurchase() public {
        uint256 minPurchase = 0;
        vm.expectRevert(
            abi.encodeWithSelector(INudixSale.BelowMinPurchase.selector, MIN_PURCHASE, minPurchase)
        );

        vm.prank(owner);
        sale.startSale(block.timestamp, minPurchase, ROUND_RATE, ROUND_CAP);
    }

    function test_startSale_success() public {
        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        Sale memory currentSale = sale.getCurrentSale();

        assertEq(currentSale.startTime, block.timestamp);
        assertEq(currentSale.minPurchase, MIN_PURCHASE);
        assertEq(currentSale.roundRate, ROUND_RATE);
        assertEq(currentSale.roundCap, ROUND_CAP);
        assertEq(currentSale.totalInvestment, 0);
        assertEq(currentSale.finalized, false);
    }

    function test_startSale_emitSaleStarted() public {
        uint8 saleId = 1;

        vm.expectEmit(true, false, false, true);
        emit INudixSale.SaleStarted(saleId, block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
    }

    function test_startSale_severalTimes() public {
        vm.startPrank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
        sale.stopSale();

        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
        sale.stopSale();

        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
        sale.stopSale();
    }

    // endregion

    // region - Stop sale -

    function test_stopSale_revertIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));

        vm.prank(hacker);
        sale.stopSale();
    }

    function test_stopSale_revertIfSaleIsFinalized() public {
        vm.startPrank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        sale.stopSale();

        vm.expectRevert(abi.encodeWithSelector(INudixSale.SaleIsFinalized.selector));

        sale.stopSale();
        vm.stopPrank();
    }

    function test_stopSale_success() public {
        vm.startPrank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        sale.stopSale();
        vm.stopPrank();

        assertEq(sale.getCurrentSale().finalized, true);
    }

    function test_stopSale_emitSaleFinalized() public {
        vm.startPrank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.expectEmit(true, false, false, false);
        emit INudixSale.SaleFinalized(sale.getCurrentSaleId());

        sale.stopSale();
        vm.stopPrank();
    }

    // endregion

    // region - Buy -

    function test_buy_revertIfSaleIsFinalized() public {
        vm.startPrank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);
        sale.stopSale();
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(INudixSale.SaleIsFinalized.selector));
        sale.buy(1);
    }

    function test_buy_revertIfSaleNotInitialized() public {
        // First case: saleId == 0
        vm.expectRevert(abi.encodeWithSelector(INudixSale.SaleNotInitialized.selector));
        vm.prank(user);
        sale.buy(VALUE);
    }

    function test_buy_revertIfSaleNotStarted() public {
        vm.prank(owner);
        sale.startSale(block.timestamp + 1 days, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.expectRevert(abi.encodeWithSelector(INudixSale.SaleNotStarted.selector));

        vm.prank(user);
        sale.buy(VALUE);
    }

    function test_buy_revertIfMaxCapReached() public {
        uint256 reachedAmount = ROUND_CAP + 1;
        paymentToken.mint(user, reachedAmount);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.expectRevert(abi.encodeWithSelector(INudixSale.MaxCapReached.selector));

        vm.prank(user);
        sale.buy(reachedAmount);
    }

    function test_buy_revertIfBelowMinPurchase(uint256 amount) public {
        amount = bound(amount, 0, MIN_PURCHASE - 1);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.expectRevert(abi.encodeWithSelector(INudixSale.BelowMinPurchase.selector, MIN_PURCHASE, amount));

        vm.prank(user);
        sale.buy(amount);
    }

    /// @dev roundRate calculation context:
    ///
    /// Note: USDT may have either 6 or 18 decimals depending on the network
    ///       (e.g., 6 decimals on Ethereum mainnet, but 18 on BNB Chain)
    ///
    /// For this example, assume USDT has 6 decimals,
    /// and Nudix has 18 decimals (standard)
    /// TOKEN_SCALE is set to 1e18 to normalize rates to 18 decimals
    ///
    /// Goal: establish a 1:1 exchange rate (1 USDT → 1 Nudix)
    ///
    /// Formula used in contract: (amount * roundRate) / TOKEN_SCALE
    ///
    /// We want to receive 1e18 Nudix tokens
    /// How much USDT should be spent? → 1e6 (i.e. 1 USDT in 6-decimal format)
    ///
    /// Plug into the formula:
    /// (1e18 * roundRate) / 1e18 = 1e6
    /// → roundRate = 1e6
    ///
    /// Therefore:
    /// - If USDT has 6 decimals, use roundRate = 1e6 for a 1:1 exchange
    /// - If USDT has 18 decimals, use roundRate = 1e18
    function test_buy_success(uint256 amount) public {
        amount = bound(amount, MIN_PURCHASE, ROUND_CAP);

        paymentToken.mint(user, amount);
        vm.prank(user);
        paymentToken.approve(address(sale), amount);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.prank(user);
        sale.buy(amount);

        assertEq(shareToken.balanceOf(user), amount);
        assertEq(paymentToken.balanceOf(user), 0);
        assertEq(paymentToken.balanceOf(wallet), sale.getPaymentAmount(amount));
        assertEq(sale.getCurrentSale().totalInvestment, amount);
    }

    function test_buy_addFinalizedFlag() public {
        paymentToken.mint(user, ROUND_CAP);
        vm.prank(user);
        paymentToken.approve(address(sale), ROUND_CAP);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.prank(user);
        sale.buy(ROUND_CAP);

        assertTrue(sale.getCurrentSale().finalized);
        assertEq(sale.getCurrentSale().totalInvestment, ROUND_CAP);
    }

    function test_buy_addFinalizedFlag_emitSaleFinalized() public {
        paymentToken.mint(user, ROUND_CAP);
        vm.prank(user);
        paymentToken.approve(address(sale), ROUND_CAP);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.expectEmit(true, false, false, false);
        emit INudixSale.SaleFinalized(sale.getCurrentSaleId());

        vm.prank(user);
        sale.buy(ROUND_CAP);
    }

    function test_buy_withDecimals6() public {
        // 1. Create NudixSale with new paymentToken
        ERC20Mock paymentTokenWithDec6 = new ERC20Mock(6);
        NudixSale saleWithDec6 = new NudixSale(address(shareToken), address(paymentTokenWithDec6), wallet, owner);
        vm.startPrank(owner);
        shareToken.grantRole(shareToken.MINTER_ROLE(), address(saleWithDec6));
        vm.stopPrank();

        // 2. Get paymentTokens
        uint256 userPaymentTokenBalance = 100e6; // for example 100 USDT
        paymentTokenWithDec6.mint(user, userPaymentTokenBalance);

        vm.prank(user);
        paymentTokenWithDec6.approve(address(saleWithDec6), userPaymentTokenBalance);

        // 3. Start sale
        uint256 roundRate = 0.5e6;
        uint256 roundCap = 100_000e6;
        vm.prank(owner);
        saleWithDec6.startSale(block.timestamp, MIN_PURCHASE, roundRate, roundCap);

        // 4. Buy tokens
        uint256 buyAmount = 100e18; // 100 shareToken

        // 100e18 * 0.5e6 = 50e6 | 100 shareToken * 0.5 USDT = 50 USDT
        uint256 expectedPrice = buyAmount * roundRate / 1e18;

        vm.prank(user);
        saleWithDec6.buy(buyAmount);

        uint256 actualPrice = saleWithDec6.getPaymentAmount(buyAmount);

        assertEq(expectedPrice, actualPrice);
        assertEq(shareToken.balanceOf(user), buyAmount);
        assertEq(paymentTokenWithDec6.balanceOf(user), userPaymentTokenBalance - actualPrice);
        assertEq(paymentTokenWithDec6.balanceOf(wallet), saleWithDec6.getPaymentAmount(buyAmount));
        assertEq(saleWithDec6.getCurrentSale().totalInvestment, expectedPrice);
    }

    function test_startSale_emitSold() public {
        paymentToken.mint(user, VALUE);
        vm.prank(user);
        paymentToken.approve(address(sale), VALUE);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        vm.expectEmit(true, false, false, true);
        emit INudixSale.Sold(user, VALUE, sale.getPaymentAmount(VALUE));

        vm.prank(user);
        sale.buy(VALUE);
    }

    // endregion

    // region - Getters -

    function test_getCurrentSaleId() public {
        assertEq(sale.getCurrentSaleId(), 0);

        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        assertEq(sale.getCurrentSaleId(), 1);
    }

    function test_getPaymentAmount() public {
        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        uint256 amount = 100e18; // 100 shareToken
        uint256 expectedPrice = amount * sale.getCurrentSale().roundRate / 1e18;
        assertEq(sale.getPaymentAmount(amount), expectedPrice);
    }

    function test_getPaymentAmount_withMinRoundRate() public {
        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, 1, ROUND_CAP);

        uint256 amount = 100e18;
        uint256 expectedPrice = amount * sale.getCurrentSale().roundRate / 1e18;
        assertEq(sale.getPaymentAmount(amount), expectedPrice);
    }

    function test_getSale() public {
        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        Sale memory saleRound = sale.getSale(sale.getCurrentSaleId());

        assertEq(saleRound.startTime, block.timestamp);
        assertEq(saleRound.minPurchase, MIN_PURCHASE);
        assertEq(saleRound.roundRate, ROUND_RATE);
        assertEq(saleRound.roundCap, ROUND_CAP);
        assertEq(saleRound.totalInvestment, 0);
        assertEq(saleRound.finalized, false);
    }

    function test_getCurrentSale() public {
        vm.prank(owner);
        sale.startSale(block.timestamp, MIN_PURCHASE, ROUND_RATE, ROUND_CAP);

        Sale memory saleRound = sale.getCurrentSale();

        assertEq(saleRound.startTime, block.timestamp);
        assertEq(saleRound.minPurchase, MIN_PURCHASE);
        assertEq(saleRound.roundRate, ROUND_RATE);
        assertEq(saleRound.roundCap, ROUND_CAP);
        assertEq(saleRound.totalInvestment, 0);
        assertEq(saleRound.finalized, false);
    }

    function test_getWallet() public view {
        assertEq(sale.getWallet(), wallet);
    }

    function test_getPaymentToken() public view {
        assertEq(sale.getPaymentToken(), address(paymentToken));
    }

    function test_getTemporaryNudix() public view {
        assertEq(sale.getTemporaryNudix(), address(shareToken));
    }

    // endregion
}
