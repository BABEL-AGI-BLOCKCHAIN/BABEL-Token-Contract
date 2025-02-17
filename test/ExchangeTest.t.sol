// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Exchange.sol";
import "../src/TopicERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract ExchangeTest is Test {
    Exchange private exchange;
    TopicERC20 private sourceToken;
    TopicERC20 private targetToken;

    address private owner = address(0x123);
    address private user = address(0x456);

    function setUp() public {

        vm.startPrank(owner);
        exchange = new Exchange(owner);
        sourceToken = new TopicERC20("SourceToken", "SRC", 10000000 * 1e18);
        targetToken = new TopicERC20("TargetToken", "TGT", 10000000 * 1e18);

        exchange.setPair(
            address(sourceToken),
            address(targetToken),
            5,
            1,
            true,
            1000 * 1e18
        );

        targetToken.transfer(address(exchange), 10000 * 1e18);
        vm.stopPrank();
    }

    function testSetPair() public {
        vm.startPrank(owner);
        exchange.setPair(
            address(sourceToken),
            address(targetToken),
            10,
            1,
            true,
            2000 * 1e18
        );

        (address targetTokenAddr, uint256 rateNum, uint256 rateDenom, bool enabled, uint256 dailyLimit) =
        exchange.pairs(address(sourceToken));

        assertEq(targetTokenAddr, address(targetToken));
        assertEq(rateNum, 10);
        assertEq(rateDenom, 1);
        assertEq(enabled, true);
        assertEq(dailyLimit, 2000 * 1e18);
        vm.stopPrank();
    }

    function testSwap() public {
        vm.prank(owner);
        sourceToken.transfer(user, 100 * 1e18);

        vm.startPrank(user);
        sourceToken.approve(address(exchange), 100 * 1e18);
        exchange.swap(address(sourceToken), 100 * 1e18);

        assertEq(sourceToken.balanceOf(user), 0);
        assertEq(targetToken.balanceOf(user), 500 * 1e18); // 100 * 5 = 500

        assertEq(sourceToken.balanceOf(address(exchange)), 100 * 1e18);
        assertEq(targetToken.balanceOf(address(exchange)), 9500 * 1e18); // 10000 - 500 = 9500
        vm.stopPrank();
    }

    function testDailyLimit() public {
        vm.prank(owner);
        sourceToken.transfer(user, 1500 * 1e18);
        vm.startPrank(user);
        sourceToken.approve(address(exchange), 1500 * 1e18);
        exchange.swap(address(sourceToken), 1000 * 1e18);
        assertEq(targetToken.balanceOf(user), 5000 * 1e18);
        vm.expectRevert("Exceeds daily limit");
        exchange.swap(address(sourceToken), 500 * 1e18);

        vm.warp(block.timestamp + 1 days);

        exchange.swap(address(sourceToken), 500 * 1e18);
        assertEq(targetToken.balanceOf(user), 7500 * 1e18);

        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.prank(owner);
        sourceToken.transfer(user, 100 * 1e18);
        vm.startPrank(user);
        sourceToken.approve(address(exchange), 100 * 1e18);
        exchange.swap(address(sourceToken), 100 * 1e18);
        vm.stopPrank();

        vm.startPrank(owner);
        exchange.withdraw(address(sourceToken), 100 * 1e18);
        assertEq(sourceToken.balanceOf(owner), 10000000 * 1e18);
        assertEq(sourceToken.balanceOf(address(exchange)), 0);
        vm.stopPrank();
    }

    // function testOnlyOwnerCanSetPair() public {
    //     vm.startPrank(user);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     exchange.setPair(
    //         address(sourceToken),
    //         address(targetToken),
    //         10,
    //         1,
    //         true,
    //         2000 * 1e18
    //     );
    //     vm.stopPrank();
    // }

    function testGetRemainingDailyLimit() public {
        uint256 remainingLimit = exchange.getRemainingDailyLimit(address(sourceToken));
        assertEq(remainingLimit, 1000 * 1e18);
        vm.prank(owner);
        sourceToken.transfer(user, 500 * 1e18);
        vm.startPrank(user);

        sourceToken.approve(address(exchange), 500 * 1e18);
        exchange.swap(address(sourceToken), 500 * 1e18);
        vm.stopPrank();

        remainingLimit = exchange.getRemainingDailyLimit(address(sourceToken));
        assertEq(remainingLimit, 500 * 1e18);
    }
}