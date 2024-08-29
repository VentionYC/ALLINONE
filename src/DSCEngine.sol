// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
contract DSCEngine {

    error DSCEng_NoZeroTxPlease();
    error DSCEng_TokenNotSupported();
    error DSCEng_TokenTransferFailed();
    error DSCEng_UserHealthFactorBroken();
    error DSCEng_DscMintFailed();
    error DSCEng_UserStillSafe();

    event RedemedCollateral(address indexed collateralOwner, address indexed tokenCollateralAddress, uint256 amountCollateral);
    event DepositCollateral(address indexed collateralOwner, address indexed tokenCollateralAddress, uint256 amountCollateral);

    DecentralizedStableCoin private immutable i_dsc;

    //State mapping for allow list of token
    mapping (address token => address priceFeed) private s_tokenToPriceFeed;
    mapping (address collateralOwner => mapping (address token => uint256 amount)) private s_collateralRecorded;
    mapping (address collateralOwner => uint256 amount) private s_dscMinted;

    address[] private s_collateral_tokens;

    modifier NoZeroTx (uint256 amount) {
        if (amount ==0) {
            revert DSCEng_NoZeroTxPlease();
        }
        _;
    }

    modifier IsSupportedToken (address token) {
        //if the token is not in the allow list then revert
        
        _;
    }
    //why passed list of tokens and priceFeeds?
    constructor(address[] memory tokens, address[] memory priceFeeds, address dsc) {
        //the length of the tokens and priceFeeds should be the same
        if(tokens.length != priceFeeds.length) {
            revert DSCEng_TokenNotSupported();
        }
        for(uint256 i=0; i<tokens.length; i++){
            s_tokenToPriceFeed[tokens[i]] = priceFeeds[i];
        }
        i_dsc = DecentralizedStableCoin(dsc);
    }

    //if someone is almost undercollaterallized, wen will pay you to liquidate them!
    function liquidate(address collateral, address user, uint256 debtToCover) external NoZeroTx(debtToCover) {
        uint256 userHealthFactor = _getTheHealthFactor(user);
        if (userHealthFactor >= 1) {
        revert DSCEng_UserStillSafe();     
        }

        //burn the dsc so called debt, and then take their collateral
        uint256 dscToBurnInCollateralToken = getTokenAmountForUSD(collateral, debtToCover);
        //10% bonus for liquidator
        uint256 bounsCollateral = (dscToBurnInCollateralToken * 10) / 100;
        //???
        uint256 totalCollateralToRedeem = dscToBurnInCollateralToken + bounsCollateral;
    }

    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDsc
    ) external NoZeroTx(amountCollateral) NoZeroTx(amountDsc) {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDsc);
    }



    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) public NoZeroTx(amountCollateral) {
                //emit event after state var is set
                //every time when depositCollateral is called, if the collateralOwner is the same, 
                //and the tokenCollateralAddress is the same, 
                //then the amountCollateral will be added accordingly
                s_collateralRecorded[msg.sender][tokenCollateralAddress] += amountCollateral;
                
                emit DepositCollateral(msg.sender, tokenCollateralAddress, amountCollateral);
                bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
                if(!success) {
                    revert DSCEng_TokenTransferFailed();
                }
    }

    function mintDsc(uint256 amountDsc) public NoZeroTx(amountDsc) {
       // for (uint i = 0; i < s_collateralRecorded.length; i++) {}
       s_dscMinted[msg.sender] += amountDsc;
       //the revert will revert the last line of the function
       _revertIfTheUserHealthFactorIsBroken(msg.sender);
       bool minted = i_dsc.mint(msg.sender, amountDsc);
       if (!minted) {
              revert DSCEng_DscMintFailed();
       }
    }

    //health factor has to be greater than 1 after redeem certain amount of collateral
    function redeemCollateral(address tokenCollateralAddress, uint256 amountOfCollateral) public NoZeroTx(amountOfCollateral) {
        s_collateralRecorded[msg.sender][tokenCollateralAddress] -= amountOfCollateral;
        emit RedemedCollateral(msg.sender, tokenCollateralAddress, amountOfCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountOfCollateral);
        if (!success) {
            revert DSCEng_TokenTransferFailed();
        }
        _revertIfTheUserHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) public NoZeroTx(amount){
        s_dscMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);

        if (!success) {
            revert DSCEng_TokenTransferFailed();  
        }
        i_dsc.burn(amount);

    }

    function redeemCollateralAndBurnDsc(address tokenCollateralAddress,
                                        uint256 amountOfCollateral,
                                        uint256 amountOfDscToBurn) external {
        burnDsc(amountOfDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountOfCollateral);   

    }

    //return how close to liquidation a user is,
    //if the user's health factor is 1, then the user is at the liqudation point
    function _revertIfTheUserHealthFactorIsBroken(address user) internal view {
        //if the user's health factor is broken, then revert
        //making get the health foactor a function
        if(_getTheHealthFactor(user) < 1) {
            revert DSCEng_UserHealthFactorBroken();
        }
    }

    function _getTheHealthFactor(address user) internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 collatearValueInUSD) = _getUserAccountInfo(user);

        return (collatearValueInUSD * 50 /100 / totalDscMinted);
    }

    function _getUserAccountInfo(address user) internal view returns (uint256 totalDscMinted, uint256 totoalCollateraler) {
        uint256 totalMinted = s_dscMinted[user];
        uint256 collateralRecorded = getUserCollateralInUSD(user);

        return (totalMinted, collateralRecorded);
    }

    //tool for the user to calculate their asset in USD
    function getUserCollateralInUSD (address user) public view returns (uint256 totalCollateraValueInUsd) {
        //loop through all the tokens in the  user account
        // we have to add another var for us to loop through all the token we have
        for (uint i = 0; i < s_collateral_tokens.length; i++) {
            address token = s_collateral_tokens[i];
            uint256 amount = s_collateralRecorded[user][token];
            //tool function, get the price of the token in USD
            totalCollateraValueInUsd += getUSDValueForToken(token, amount);
        }

        return totalCollateraValueInUsd;
    }

    function getUSDValueForToken(address token, uint256 amount) public view returns (uint256 valueInUSD) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();

        return (uint256(price) * 1e10 * amount)/ 1e18;
    }

    function getTokenAmountForUSD(address token, uint256 USDValueInWei) public view returns (uint256 tokenAmount) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        //(uint256(price) * 1e10 * returnAmount)/ 1e18 = USDValue
        //returnAmount = USDValue * 1e18 / (uint256(price) * 1e10)
        return (USDValueInWei * 1e18) / (uint256(price) * 1e10);
    }


    

}