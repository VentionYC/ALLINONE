// SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";


contract DSCEngineTest is Test {

    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    
    
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    address public USER = makeAddr("user");

    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL = 1 ether;

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, helperConfig) =  deployer.run();
        (ethUsdPriceFeed, ,weth , , ) = helperConfig.activeNetworkConfig();   
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock unapprovedToken = new ERC20Mock("UNAPPROVED", "UNAPPROVED", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEng_TokenNotSupported.selector);
        dsce.depositCollateral(address(unapprovedToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
    
    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral{
        (uint256 dscMinted, uint256 collateralAmount) = dsce.getAccountInfo(USER);  
        uint256 expectedTotalCollateralInUsd = dsce.getUSDValueForToken(weth, AMOUNT_COLLATERAL);
        assertEq(dscMinted, 0);
        assertEq(expectedTotalCollateralInUsd, collateralAmount);


    }

    //test for the constructor
    function testRevertWhenTokensNotMatchingPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEng_TokenNotSupported.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //the most important, test for get the usd value for the token
    //price test

    function testGetUsdValueForToken() public view {
        uint256 ethAmount = 1e18;
        // 1e18 * 2000/ETH = 2000e18
        uint256 expectedUsdValue = 2000e18;
        uint256 actualUsdValue = dsce.getUSDValueForToken(weth, ethAmount);
        assertEq(actualUsdValue, expectedUsdValue);
    }

    function testGetTokenAmountForUSD() public view {
        uint256 usdValueInWei = 2000e18;
        // 2000e18 / 2000/ETH = 1e18
        uint256 expectedTokenAmount = 1e18;
        uint256 actualTokenAmount = dsce.getTokenAmountForUSD(weth, usdValueInWei);
        assertEq(actualTokenAmount, expectedTokenAmount);
    }


    //dipositCollateral test

    function testRevertsIfCollateralAmountIsZero() public{
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), 1e18);

        vm.expectRevert(DSCEngine.DSCEng_NoZeroTxPlease.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

}