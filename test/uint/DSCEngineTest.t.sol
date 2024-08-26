// SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DSCEngineTest is Test {

    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;
    //address btcUsdPriceFeed;
    //address wbtc;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, helperConfig) =  deployer.run();
        (ethUsdPriceFeed, weth, , , ) = helperConfig.activeNetworkConfig();    }

    //the most important, test for get the usd value for the token
    //price test

    function testGetUsdValueForToken() public view {
        uint256 ethAmount = 1e18;
        // 1e18 * 2000/ETH = 2000e18
        uint256 expectedUsdValue = 2000e18;
        uint256 actualUsdValue = dsce.getUSDValueForToken(weth, ethAmount);
        assertEq(actualUsdValue, expectedUsdValue);
    }
}