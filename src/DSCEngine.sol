// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {DecentralizedStableCoin} from "./DecentrailzedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
contract DSCEngine {

    error DSCEng_NoZeroTxPlease();
    error DSCEng_TokenNotSupported();
    error DSCEng_TokenTransferFailed();
    error DSCEng_UserHealthFactorBroken();

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


    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external NoZeroTx(amountCollateral) {
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
    

}