// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {DecentralizedStableCoin} from "./DecentrailzedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DSCEngine {

    error DSCEng_NoZeroTxPlease();
    error DSCEng_TokenNotSupported();
    error DSCEng_TokenTransferFailed();

    event DepositCollateral(address indexed collateralOwner, address indexed tokenCollateralAddress, uint256 amountCollateral);

    DecentralizedStableCoin private immutable i_dsc;

    //State mapping for allow list of token
    mapping (address token => address priceFeed) private s_tokenToPriceFeed;
    mapping (address collateralOwner => mapping (address token => uint256 amount)) private s_collateralRecorded;

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

}