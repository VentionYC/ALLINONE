// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract DSCEngine {

    error DSCEng_NoZeroTxPlease();

    //State mapping for allow list of token
    mapping (address => bool) s_tokenToAllowed;

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

    constructor() {}


    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external NoZeroTx(amountCollateral) {
        
    }

}