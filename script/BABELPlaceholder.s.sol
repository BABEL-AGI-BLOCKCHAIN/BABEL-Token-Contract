pragma solidity ^0.8.20;
import {Script} from "forge-std/Script.sol";
import "../src/BABELPlaceholder.sol";

contract BABELPlaceholderScript is Script {
    function run() external returns (BABELPlaceholder) {
        vm.startBroadcast();
        BABELPlaceholder erc20 = new BABELPlaceholder(
            "BABEL placeholder",
            "BABEL placeholder",
            21000000 * 1e18
        );
        vm.stopBroadcast();
        return erc20;
    }
}
