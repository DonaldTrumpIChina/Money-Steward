// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {NetworkConfig} from "./NetworkConfig.s.sol";
import {Guard} from "../src/protocol/Guard.sol";
import {VaultGuardianGovernor} from "../src/dao/VaultGuardianGovernor.sol";
import {VaultGuardianToken} from "../src/dao/VaultGuardianToken.sol";

contract DeployGuard is Script {
    function run() external returns (Guard, VaultGuardianGovernor, VaultGuardianToken, NetworkConfig) {
        NetworkConfig networkConfig = new NetworkConfig(); // This comes with our mocks!
        (address aavePool, address uniswapRouter, address weth, address usdc, address link) =
            networkConfig.activeNetworkConfig();

        vm.startBroadcast();
        VaultGuardianToken vgToken = new VaultGuardianToken(); // mints us the total supply
        VaultGuardianGovernor vgGovernor = new VaultGuardianGovernor(vgToken);
        Guard Guard = new Guard(
            aavePool,
            uniswapRouter,
            weth,
            usdc,
            link, 
            address(vgToken)
        );
        Guard.transferOwnership(address(vgGovernor));
        vgToken.transferOwnership(address(Guard));
        vm.stopBroadcast();
        return (Guard, vgGovernor, vgToken, networkConfig);
    }

    // add this to be excluded from coverage report
    function test() public {}
}
