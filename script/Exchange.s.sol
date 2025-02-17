pragma solidity ^0.8.20;
import {Script} from "forge-std/Script.sol";
import "../src/Exchange.sol";

contract ExchangeScript is Script {
    function run() external returns(Exchange){
        vm.startBroadcast();
        Exchange ex = new Exchange(msg.sender);
        vm.stopBroadcast();
        return ex;
    }
}