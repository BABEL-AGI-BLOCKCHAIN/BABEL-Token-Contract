// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Exchange.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract ExchangeTest is Test {
    Exchange private exchange;
    MockERC20 private tokenA;
    MockERC20 private tokenB;

    address private owner = address(0x123);
    address private user = address(0x456);

    function setUp() public {
        // 部署合约
        vm.startPrank(owner);
        exchange = new Exchange(owner);
        MockERC20 token1 = new MockERC20("TokenA", "A");
        MockERC20 token2 = new MockERC20("TokenB", "B");
        
        if(address(token1) < address(token2)) {
            tokenA = token1;
            tokenB = token2;
        } else {
            tokenA = token2;
            tokenB = token1;
        }

        tokenA.mint(address(exchange), 10000 * 1e18);
        tokenB.mint(address(exchange), 10000 * 1e18);
        // 设置货币对（A -> B）
        exchange.setPair(
            address(tokenA),
            address(tokenB),
            5, // 1 A = 5 B（正向）
            1,
            1, // 5 B = 1 A（反向）
            5,
            true,
            1000 * 1e18 // 每日限额 1000 A
        );
        vm.stopPrank();
    }

    // 测试设置重复货币对（B -> A）
    function testSetDuplicatePair() public {
        vm.startPrank(owner);

        // 尝试设置 B -> A 的货币对（应失败）
        vm.expectRevert("Pair already exists");
        exchange.setPair(
            address(tokenB),
            address(tokenA),
            1, // 1 B = 0.2 A（正向）
            5,
            5, // 0.2 A = 1 B（反向）
            1,
            true,
            1000 * 1e18 // 每日限额 1000 B
        );

        vm.stopPrank();
    }

    // 测试正向兑换（A -> B）
    function testSwap() public {
        tokenA.mint(user, 100 * 1e18);
        
        vm.startPrank(user);
        tokenA.approve(address(exchange), 100 * 1e18);
        exchange.swap(address(tokenA), address(tokenB), 100 * 1e18);

        // 检查用户余额
        assertEq(tokenA.balanceOf(user), 0);
        assertEq(tokenB.balanceOf(user), 500 * 1e18); // 100 * 5 = 500
        vm.stopPrank();
    }

    // 测试反向兑换（B -> A）
    function testReverseSwap() public {
        tokenB.mint(user, 500 * 1e18);
        vm.startPrank(user);
        tokenB.approve(address(exchange), 500 * 1e18);
        exchange.swap(address(tokenB), address(tokenA), 500 * 1e18);

        // 检查用户余额
        assertEq(tokenB.balanceOf(user), 0);
        assertEq(tokenA.balanceOf(user), 100 * 1e18); // 500 / 5 = 100
        vm.stopPrank();
    }
}