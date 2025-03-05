// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract Exchange is Ownable {
    using SafeERC20 for IERC20;

    struct TokenPair {
        uint256 rateNumerator;   // 正向兑换比例分子（source -> target）
        uint256 rateDenominator; // 正向兑换比例分母
        uint256 reverseRateNumerator;   // 反向兑换比例分子（target -> source）
        uint256 reverseRateDenominator; // 反向兑换比例分母
        bool enabled;           // 是否启用
        uint256 dailyLimit;     // 每日限额（以源代币为单位）
    }

    // 嵌套映射：sourceToken => targetToken => TokenPair
    mapping(address => mapping(address => TokenPair)) private pairs;
    // 每日已兑换量记录：sourceToken => targetToken => day => amount
    mapping(address => mapping(address => mapping(uint256 => uint256))) public dailySwapped;

    event PairUpdated(
        address indexed sourceToken,
        address indexed targetToken,
        uint256 rateNumerator,
        uint256 rateDenominator,
        uint256 reverseRateNumerator,
        uint256 reverseRateDenominator,
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

    constructor(address initialOwner) Ownable(initialOwner) {

    }


    function getPairs(address token1, address token2) public view returns(uint256,uint256,uint256,uint256,bool,uint256) {
        (address tokenA, address tokenB) = _sortTokens(token1, token2);
        TokenPair memory pair = pairs[tokenA][tokenB];
        return (pair.rateNumerator,pair.rateDenominator,pair.reverseRateNumerator,pair.reverseRateDenominator,pair.enabled,pair.dailyLimit);
    }

    // 检查货币对是否已存在
    function isPairExists(address token1, address token2) public view returns (bool) {
        (address tokenA, address tokenB) = _sortTokens(token1, token2);
        return pairs[tokenA][tokenB].rateNumerator > 0 || pairs[token2][token1].rateNumerator > 0;
    }

    // 添加/更新货币对（仅管理员）
    function setPair(
        address sourceToken,
        address targetToken,
        uint256 rateNumerator,
        uint256 rateDenominator,
        uint256 reverseRateNumerator,
        uint256 reverseRateDenominator,
        bool enabled,
        uint256 dailyLimit
    ) external onlyOwner {
        require(sourceToken != address(0), "Invalid source token");
        require(targetToken != address(0), "Invalid target token");
        require(sourceToken != targetToken, "Source and target tokens must be different");
        require(rateNumerator > 0, "Invalid numerator");
        require(rateDenominator > 0, "Invalid denominator");
        require(reverseRateNumerator > 0, "Invalid reverse numerator");
        require(reverseRateDenominator > 0, "Invalid reverse denominator");

        // 检查货币对是否已存在
        require(!isPairExists(sourceToken, targetToken), "Pair already exists");

        (address tokenA, address tokenB) = _sortTokens(sourceToken, targetToken);
        if (tokenA == targetToken) {
            uint256 a = rateNumerator;
            rateNumerator = reverseRateNumerator;
            reverseRateNumerator = a;

            uint256 b = rateDenominator;
            rateDenominator = reverseRateDenominator;
            reverseRateDenominator = b;
        }

        pairs[tokenA][tokenB] = TokenPair({
            rateNumerator: rateNumerator,
            rateDenominator: rateDenominator,
            reverseRateNumerator: reverseRateNumerator,
            reverseRateDenominator: reverseRateDenominator,
            enabled: enabled,
            dailyLimit: dailyLimit
        });

        emit PairUpdated(
            sourceToken,
            targetToken,
            rateNumerator,
            rateDenominator,
            reverseRateNumerator,
            reverseRateDenominator,
            enabled,
            dailyLimit
        );
    }

    function swap(
        address sourceToken, 
        address targetToken,
        uint256 sourceAmount
    ) external {
        (address tokenA, address tokenB) = _sortTokens(sourceToken, targetToken);
        if (tokenA == sourceToken) {
            _swap(sourceToken, targetToken, sourceAmount);
        } else {
            _reverseSwap(sourceToken, targetToken, sourceAmount);
        }
    }

    // 执行正向兑换（source -> target）
    function _swap(
        address sourceToken,
        address targetToken,
        uint256 sourceAmount
    ) internal {
        TokenPair memory pair = pairs[sourceToken][targetToken];
        require(pair.rateNumerator > 0, "Pair not exists");
        require(pair.enabled, "Pair disabled");
        require(sourceAmount > 0, "Invalid amount");

        // 计算目标代币数量
        uint256 targetAmount = (sourceAmount * pair.rateNumerator) / pair.rateDenominator;
        require(targetAmount > 0, "Invalid target amount");

        // 检查合约余额是否足够
        IERC20 targetTokenContract = IERC20(targetToken);
        require(
            targetTokenContract.balanceOf(address(this)) >= targetAmount,
            "Insufficient liquidity"
        );

        // 检查每日限额
        uint256 today = block.timestamp / 1 days;
        uint256 swappedToday = dailySwapped[sourceToken][targetToken][today];
        require(
            swappedToday + sourceAmount <= pair.dailyLimit,
            "Exceeds daily limit"
        );

        // 更新已兑换量
        dailySwapped[sourceToken][targetToken][today] = swappedToday + sourceAmount;

        // 转移源代币
        IERC20(sourceToken).safeTransferFrom(
            msg.sender,
            address(this),
            sourceAmount
        );

        // 发放目标代币
        targetTokenContract.safeTransfer(msg.sender, targetAmount);

        emit Swapped(
            msg.sender,
            sourceToken,
            targetToken,
            sourceAmount,
            targetAmount
        );
    }

    // 执行反向兑换（target -> source）
    function _reverseSwap(
        address targetToken,
        address sourceToken,
        uint256 targetAmount
    ) internal {
        TokenPair memory pair = pairs[sourceToken][targetToken];
        require(pair.rateNumerator > 0, "Pair not exists");
        require(pair.enabled, "Pair disabled");
        require(targetAmount > 0, "Invalid amount");

        // 计算源代币数量
        uint256 sourceAmount = (targetAmount * pair.reverseRateNumerator) / pair.reverseRateDenominator;
        require(sourceAmount > 0, "Invalid source amount");
        // 检查合约余额是否足够
        IERC20 sourceTokenContract = IERC20(sourceToken);
        require(
            sourceTokenContract.balanceOf(address(this)) >= sourceAmount,
            "Insufficient liquidity"
        );

        // 检查每日限额
        uint256 today = block.timestamp / 1 days;
        uint256 swappedToday = dailySwapped[sourceToken][targetToken][today];
        require(
            swappedToday + sourceAmount <= pair.dailyLimit,
            "Exceeds daily limit"
        );

        // 更新已兑换量
        dailySwapped[sourceToken][targetToken][today] = swappedToday + sourceAmount;

        // 转移目标代币
        IERC20(targetToken).safeTransferFrom(
            msg.sender,
            address(this),
            targetAmount
        );

        // 发放源代币
        sourceTokenContract.safeTransfer(msg.sender, sourceAmount);

        emit Swapped(
            msg.sender,
            targetToken,
            sourceToken,
            targetAmount,
            sourceAmount
        );
    }

    // 提取代币（仅管理员）
    function withdraw(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawn(token, amount);
    }


    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
}