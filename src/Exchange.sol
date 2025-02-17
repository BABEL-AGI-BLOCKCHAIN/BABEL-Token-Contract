// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Exchange is Ownable {
    using SafeERC20 for IERC20;

    struct TokenPair {
        address targetToken;
        uint256 rateNumerator;
        uint256 rateDenominator;
        bool enabled;
        uint256 dailyLimit;
    }

    mapping(address => TokenPair) public pairs;
    mapping(address => mapping(uint256 => uint256)) public dailySwapped;

    event PairUpdated(
        address indexed sourceToken,
        address indexed targetToken,
        uint256 rateNumerator,
        uint256 rateDenominator,
        bool enabled,
        uint256 dailyLimit
    );
    event Swapped(
        address indexed user,
        address indexed sourceToken,
        address indexed targetToken,
        uint256 sourceAmount,
        uint256 targetAmount
    );
    event Withdrawn(address indexed token, uint256 amount);
    event DailyLimitUpdated(address indexed sourceToken, uint256 newLimit);

    constructor(address initialOwner) Ownable(initialOwner) {

    }

    function setPair(
        address sourceToken,
        address targetToken,
        uint256 rateNumerator,
        uint256 rateDenominator,
        bool enabled,
        uint256 dailyLimit
    ) external onlyOwner {
        require(sourceToken != address(0), "Invalid source token");
        require(targetToken != address(0), "Invalid target token");
        require(rateNumerator > 0, "Invalid numerator");
        require(rateDenominator > 0, "Invalid denominator");

        pairs[sourceToken] = TokenPair({
        targetToken: targetToken,
        rateNumerator: rateNumerator,
        rateDenominator: rateDenominator,
        enabled: enabled,
        dailyLimit: dailyLimit
        });

        emit PairUpdated(
            sourceToken,
            targetToken,
            rateNumerator,
            rateDenominator,
            enabled,
            dailyLimit
        );
    }

    function setDailyLimit(address sourceToken, uint256 newLimit)
    external
    onlyOwner
    {
        require(pairs[sourceToken].targetToken != address(0), "Pair not exists");
        pairs[sourceToken].dailyLimit = newLimit;
        emit DailyLimitUpdated(sourceToken, newLimit);
    }

    function swap(address sourceToken, uint256 sourceAmount) external {
        TokenPair memory pair = pairs[sourceToken];
        require(pair.targetToken != address(0), "Pair not exists");
        require(pair.enabled, "Pair disabled");
        require(sourceAmount > 0, "Invalid amount");

        uint256 targetAmount = (sourceAmount * pair.rateNumerator) /
        pair.rateDenominator;
        require(targetAmount > 0, "Invalid target amount");

        IERC20 targetToken = IERC20(pair.targetToken);
        require(
            targetToken.balanceOf(address(this)) >= targetAmount,
            "Insufficient liquidity"
        );

        uint256 today = block.timestamp / 1 days;
        uint256 swappedToday = dailySwapped[sourceToken][today];
        require(
            swappedToday + sourceAmount <= pair.dailyLimit,
            "Exceeds daily limit"
        );

        dailySwapped[sourceToken][today] = swappedToday + sourceAmount;

        IERC20(sourceToken).safeTransferFrom(
            msg.sender,
            address(this),
            sourceAmount
        );
        targetToken.safeTransfer(msg.sender, targetAmount);

        emit Swapped(
            msg.sender,
            sourceToken,
            pair.targetToken,
            sourceAmount,
            targetAmount
        );
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawn(token, amount);
    }

    function getRemainingDailyLimit(address sourceToken)
    external
    view
    returns (uint256)
    {
        TokenPair memory pair = pairs[sourceToken];
        require(pair.targetToken != address(0), "Pair not exists");

        uint256 today = block.timestamp / 1 days;
        uint256 swappedToday = dailySwapped[sourceToken][today];

        if (pair.dailyLimit > swappedToday) {
            return pair.dailyLimit - swappedToday;
        } else {
            return 0;
        }
    }
}