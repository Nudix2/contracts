// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @notice Sale round configuration
 * @param startTime Unix timestamp when sale becomes active (in seconds)
 * @param minPurchase Minimum amount of tokens user can buy (in TemporaryNudix units)
 * @param roundRate Exchange rate for the round in paymentToken
 * @param roundCap Maximum total investment in paymentToken
 * @param totalInvestment Total collected funds in current round (in paymentToken)
 * @param finalized Flag indicating if sale round is closed
 */
struct Sale {
    uint256 startTime;
    uint256 minPurchase;
    uint256 roundRate;
    uint256 roundCap;
    uint256 totalInvestment;
    bool finalized;
}

interface INudixSale {
    /// @notice Thrown when the purchase amount is below required minimum
    error BelowMinPurchase(uint256 requiredMinimum, uint256 actualAmount);

    /// @notice Thrown when trying to start a new sale while current one is still active
    error CurrentSaleMustNotBeActive();

    /// @notice Thrown when sale start time is in the past
    error IncorrectStartTime();

    /// @notice Thrown when purchase would exceed the cap of the round
    error MaxCapReached();

    /// @notice Thrown when sale has already been finalized
    error SaleIsFinalized();

    /// @notice Thrown when attempting to interact with an uninitialized sale
    error SaleNotInitialized();

    /// @notice Thrown when trying to buy before the sale start time
    error SaleNotStarted();

    /// @notice Thrown when a required address parameter is zero
    error ZeroAddress();

    /// @notice Thrown when a required numeric parameter is zero
    error ZeroParam();

    /// @notice Emitted when a new sale round is started
    event SaleStarted(
        uint8 indexed saleId,
        uint256 startTime,
        uint256 minPurchase,
        uint256 roundRate,
        uint256 roundCap
    );

    /// @notice Emitted when the current sale is finalized manually or via cap
    event SaleFinalized(uint8 indexed saleId);

    /// @notice Emitted on successful token purchase
    event Sold(address indexed buyer, uint256 amount, uint256 price);

    function buy(uint256 amount) external;
    function startSale(uint256 startTime, uint256 minPurchase, uint256 roundRate, uint256 roundCap) external;
    function stopSale() external;
    function getCurrentSaleId() external view returns (uint8);
    function getCurrentPrice(uint256 amount) external view returns (uint256);
    function getCurrentSale() external view returns (Sale memory);
    function getSale(uint8 saleId) external view returns (Sale memory);
    function getWallet() external view returns (address);
    function getPaymentToken() external view returns (address);
    function getShareToken() external view returns (address);
}