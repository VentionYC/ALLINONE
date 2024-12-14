// SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {MockFailedTransferFromMethod} from "../mocks/MockFailedTransferFromMethod.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";



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
    uint256 public constant AMOUNT_TO_MINT = 5 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;



    modifier depositedCollateral(){
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);  
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralandMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);//10ehter
        uint256 mintInUsd = dsce.getUSDValueForToken(weth, AMOUNT_TO_MINT);//5ether
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, mintInUsd);
        vm.stopPrank();
        _;
    }


    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, helperConfig) =  deployer.run();
        (ethUsdPriceFeed, ,weth , , ) = helperConfig.activeNetworkConfig();   
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

        //------------------- constructor test ----------------------------
    function testRevertWhenTokensNotMatchingPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEng_TokenNotSupported.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testRevertIfUserHealthFactorBrokeAfterMint() public depositedCollateral{
        //(uint256 dscMinted, uint256 collateralAmount) = dsce.getAccountInfo(USER);
        uint256 collateralInUsd = dsce.getUSDValueForToken(weth, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEng_UserHealthFactorBroken.selector);
        dsce.mintDsc(collateralInUsd/2+1, USER);
    }

     //--------------------------liquidate test--------------------------------

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


    //--------------------dipositCollateral test-----------------------------


    /*function testFailedTransferWhenDeposit() public {
        //Arrange - Depoly a new DSC contract to set the TransferFrom return false
        address owner = msg.sender;
        //Deploy the new fake DSC contract
        //actually this should not called DSC contract
        //, it should be ERC20 token contract
        //OK fine maybe it is called properly sicne this is the token and dsc address at the same time 
        vm.prank(owner);
        MockFailedTransferFromMethod mockDsc = new MockFailedTransferFromMethod();
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
        //bytes4 selector = bytes4(keccak256("DSCEng_TokenTransferFailed()"));
        // Log the selector using Foundry's console
        //console.logBytes4(selector);
        //vm.expectRevert("DSCEng_TokenTransferFailed");
        vm.expectRevert(DSCEngine.DSCEng_TokenTransferFailedOps.selector);
        mockDsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank(); 
    }*/

    function testOnlyRevert() public {
        vm.expectRevert(DSCEngine.DSCEng_TokenTransferFailedOps.selector);
        dsce.onlyRevert();
    }

    function testRevertsIfCollateralAmountIsZero() public{
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), 1e18);
        vm.expectRevert(DSCEngine.DSCEng_NoZeroTxPlease.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock unapprovedToken = new ERC20Mock("UNAPPROVED", "UNAPPROVED", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEng_TokenNotSupported.selector);
        dsce.depositCollateral(address(unapprovedToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testTheHealthFactorCanGoBelowOne() public depositedCollateralandMintedDsc{
        int256 ethUsdUpdatedPrice = 1999 * 1e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = dsce.getTheHealthFactor(USER);
        //uint256 totalMinted;
        //uint256 totalCollateral;
        //(totalMinted, totalCollateral) = dsce.getAccountInfo(USER);
        //console.log(totalMinted);
        //console.log(totalCollateral);
        //console.log(userHealthFactor);
        assertTrue(userHealthFactor < 1);

    }

    function testGetAccountInfo() public depositedCollateralandMintedDsc{
        uint256 actualTotalMinted;
        uint256 actualTotalCollateral;
        (actualTotalMinted, actualTotalCollateral) = dsce.getAccountInfo(USER);
        uint256 expectedMintedInUsd = dsce.getUSDValueForToken(weth, AMOUNT_TO_MINT);
        uint256 expectedCollateralInUsd = dsce.getUSDValueForToken(weth, AMOUNT_COLLATERAL);
        assertEq(actualTotalMinted, expectedMintedInUsd);
        assertEq(actualTotalCollateral, expectedCollateralInUsd);
    }

    function testGetUserCollateralInUSD() public depositedCollateralandMintedDsc{
        uint256 expectedUserCollateralInUsd = dsce.getUSDValueForToken(weth, AMOUNT_COLLATERAL);
        uint256 actualUserCollateralInUsd = dsce.getUserCollateralInUSD(USER);
        assertEq(expectedUserCollateralInUsd, actualUserCollateralInUsd);
    }


    //-----------------------price test--------------------------------
    function testGetUsdValueForToken() public view {
        uint256 ethAmount = 1e18;
        // 1e18 * 2000/ETH = 2000e18
        //2000e8 is the USD value * 1e8
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



}