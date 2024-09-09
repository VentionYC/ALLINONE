// SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {console} from "forge-std/console.sol";


contract DSCEngineTest is Test {

    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;
    
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;
    
    
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");

    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 4 ether;
    uint256 public constant AMOUNT_COLLATERAL = 9 ether;

    modifier depositedCollateral(){
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

    function testRevertIfUserHealthFactorBrokeAfterMint() public depositedCollateral{
        //(uint256 dscMinted, uint256 collateralAmount) = dsce.getAccountInfo(USER);
        uint256 collateralInUsd = dsce.getUSDValueForToken(weth, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEng_UserHealthFactorBroken.selector);
        dsce.mintDsc(collateralInUsd/2+1, USER);
    }

      //////////////////  
     //liquidate test//
    //////////////////

    //we didn't prank a diff persion than the USER as liquidator in this test
    function testRevertIfUserIsHealthyDuringLiquidate() public depositedCollateral{
        //I have to mint some DSC to the USER account
        uint256 collateralInUsd = dsce.getUSDValueForToken(weth, AMOUNT_COLLATERAL);
        dsce.mintDsc(collateralInUsd/10, USER);
        //I don't have to drop the price because what I want to test is the healthy condition
        vm.expectRevert(DSCEngine.DSCEng_UserStillSafe.selector);
        dsce.liquidate(weth, USER,collateralInUsd/10);
    }


    function testRevertIfUserIsHealthyDuringLiquidateWithDifferentLiquidator() public depositedCollateralandMintedDsc{
        // Of course, the user have to deposit some collateral first
        // and also we need to fake another address for the liqudator
        vm.startPrank(LIQUIDATOR);
        //and I guess I have to mint some weth for the liqudator
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);   
        vm.expectRevert(DSCEngine.DSCEng_UserStillSafe.selector);
        dsce.liquidate(weth, USER, AMOUNT_COLLATERAL);
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

    function testFailedTransferWhenDeposit() public {
        //Arrange - Depoly a new DSC contract to set the TransferFrom return false
        address owner = msg.sender;
        //Deploy the new fake DSC contract
        vm.prank(owner);
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];

        //Depoly the new Fake DSC engine contract,
        //And mint some DSC to the user account
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        //simulate the starting balance in the setup() function
        mockDsc.mint(USER, AMOUNT_COLLATERAL);

        //Transfer the ownership like we did in the DeployDSC script
        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));

        vm.startPrank(USER);
        //For the deposit part,first we need to approve the contract to spend the money
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), AMOUNT_COLLATERAL);

        //vm.expectRevert(DSCEngine.DSCEng_TokenTransferFailed.selector);

        // Calculate the selector for DSCEng_TokenTransferFailed
        bytes4 selector = bytes4(keccak256("DSCEng_TokenTransferFailed()"));

        // Log the selector using Foundry's console
        console.logBytes4(selector);
        vm.expectRevert("DSCEng_TokenTransferFailed");
    
        mockDsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank();

        
    }

    modifier depositedCollateralandMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        uint256 mintInUsd = dsce.getUSDValueForToken(weth, AMOUNT_TO_MINT);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, mintInUsd);
        vm.stopPrank();
        _;
    }

    //redeemCollateral test
    function testRedeemCollateral() public depositedCollateralandMintedDsc{

    }



}