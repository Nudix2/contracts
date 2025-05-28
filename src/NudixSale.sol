// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {INudixSale, Sale} from "src/interfaces/INudixSale.sol";
import {ITemporaryNudix} from "src/interfaces/ITemporaryNudix.sol";

/**
 * @title NudixSale
 * @notice Smart contract to manage token sale rounds for TemporaryNudix tokens.
 * @dev Each sale round has its own configuration including startTime, rate, cap, and minimum purchase.
 */
contract NudixSale is INudixSale, Ownable, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    /// @notice TemporaryNudix token contract
    ITemporaryNudix private immutable _temporaryNudix;

    /// @notice ERC20 token used as a payment medium (e.g., USDT, USDC)
    IERC20 private immutable _paymentToken;

    /// @notice Token scale is equal to 1 temporary Nudix
    uint256 private immutable _tokenScale;

    /// @notice Address receiving the collected funds
    address private immutable _wallet;

    /// @dev ID of the current sale round
    uint8 private _saleId;

    /// @dev Mapping of sale round IDs to Sale configurations
    mapping(uint8 saleId => Sale) private _sales;

    /// @dev Modifier to ensure sale is not finalized
    modifier whenNotFinalized() {
        if (_sales[_saleId].finalized) {
            revert SaleIsFinalized();
        }

        _;
    }

    constructor(address temporaryNudix, address paymentToken, address wallet, address initialOwner)
        Ownable(initialOwner)
    {
        if (temporaryNudix == address(0) || paymentToken == address(0) || wallet == address(0)) {
            revert ZeroAddress();
        }

        _temporaryNudix = ITemporaryNudix(temporaryNudix);
        _paymentToken = IERC20(paymentToken);
        _wallet = wallet;

        _tokenScale = 10 ** _temporaryNudix.decimals();
    }

    // region - Buy -

    /**
     * @notice Buy TemporaryNudix tokens in the active sale round
     * @param amount Amount of tokens (in TemporaryNudix units) to purchase
     * @dev Transfers paymentToken from sender to wallet and mints TemporaryNudix tokens
     */
    function buy(uint256 amount) external nonReentrant whenNotFinalized {
        uint8 currentSaleId = getCurrentSaleId();
        Sale memory currentSale = _sales[currentSaleId];

        if (currentSaleId == 0) {
            revert SaleNotInitialized();
        }

        if (block.timestamp < currentSale.startTime) {
            revert SaleNotStarted();
        }

        if (amount < currentSale.minPurchase) {
            revert BelowMinPurchase(currentSale.minPurchase, amount);
        }

        uint256 paymentAmount = getPaymentAmount(amount);
        assert(paymentAmount > 0);

        uint256 currentTotalInvestment = currentSale.totalInvestment + paymentAmount;
        if (currentTotalInvestment > currentSale.roundCap) {
            revert MaxCapReached();
        }

        bool isFinalized = currentTotalInvestment == currentSale.roundCap
            || currentSale.roundCap - currentTotalInvestment < getPaymentAmount(currentSale.minPurchase);
        if (isFinalized) {
            _sales[currentSaleId].finalized = true;
            emit SaleFinalized(currentSaleId);
        }

        _sales[currentSaleId].totalInvestment += paymentAmount;

        _paymentToken.safeTransferFrom(msg.sender, _wallet, paymentAmount);
        _temporaryNudix.mint(msg.sender, amount);

        emit Sold(msg.sender, amount, paymentAmount);
    }

    // endregion

    // region - Sale admin functions -

    /**
     * @notice Starts a new token sale round with specified parameters
     * @param startTime Unix timestamp when sale becomes active (in seconds)
     * @param minPurchase Minimum amount of tokens user can buy (in TemporaryNudix units)
     * @param roundRate Exchange rate for the round in paymentToken
     * @param roundCap Maximum total investment in paymentToken
     * @dev Only callable by the contract owner
     */
    function startSale(uint256 startTime, uint256 minPurchase, uint256 roundRate, uint256 roundCap)
        external
        onlyOwner
    {
        uint8 currentSaleId = getCurrentSaleId();
        if (currentSaleId != 0 && !_sales[currentSaleId].finalized) {
            revert CurrentSaleMustNotBeActive();
        }

        if (startTime < block.timestamp) {
            revert IncorrectStartTime();
        }

        if (roundRate == 0 || roundCap == 0) {
            revert ZeroParam();
        }

        if (minPurchase < _tokenScale) {
            revert BelowMinPurchase(_tokenScale, minPurchase);
        }

        _saleId += 1;
        _sales[_saleId] = Sale(startTime, minPurchase, roundRate, roundCap, 0, false);

        emit SaleStarted(_saleId, startTime, minPurchase, roundRate, roundCap);
    }

    /**
     * @notice Stops the current sale round prematurely
     * @dev Only callable by the contract owner
     */
    function stopSale() external onlyOwner whenNotFinalized {
        _sales[_saleId].finalized = true;

        emit SaleFinalized(_saleId);
    }

    // endregion

    // region - Getters -

    /**
     * @notice Returns ID of the current sale round
     * @return Current sale round ID
     */
    function getCurrentSaleId() public view returns (uint8) {
        return _saleId;
    }

    /**
     * @notice Calculates price in paymentToken for given token amount
     * @param amount Token amount in TemporaryNudix units
     * @return Payment token amount
     * @dev The calculation is performed taking into account the TemporaryNudix decimals
     */
    function getPaymentAmount(uint256 amount) public view returns (uint256) {
        return (amount * _sales[_saleId].roundRate) / _tokenScale;
    }

    /**
     * @notice Returns configuration of current sale round
     * @return Sale struct of current sale
     */
    function getCurrentSale() external view returns (Sale memory) {
        return _sales[_saleId];
    }

    /**
     * @notice Returns configuration of a specific sale round
     * @param saleId ID of the sale round
     * @return Sale struct
     */
    function getSale(uint8 saleId) external view returns (Sale memory) {
        return _sales[saleId];
    }

    /**
     * @notice Returns address of the payment receiver wallet
     * @return Wallet address
     */
    function getWallet() external view returns (address) {
        return _wallet;
    }

    /**
     * @notice Returns address of the payment ERC20 token
     * @return Payment token contract address
     */
    function getPaymentToken() external view returns (address) {
        return address(_paymentToken);
    }

    /**
     * @notice Returns address of the TemporaryNudix token
     * @return TemporaryNudix contract address
     */
    function getTemporaryNudix() external view returns (address) {
        return address(_temporaryNudix);
    }

    // endregion
}
