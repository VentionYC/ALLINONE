// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Vention Young
 * @notice 
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable{
    error DSC_TooPoor();
    error DSC_TooCheap();
    error DSC_NoZeroAddress();
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(0x182D0E24224193EB885a108A6246d1A3470e4613){}
    
    //There are two function which we would like our Engine contract to OWN

    function burn(uint256 value) public override onlyOwner {
        //get the balance on who is calling
        uint256 balance = balanceOf(msg.sender);
        if(value <=0){
            revert DSC_TooCheap();
        }

        if (balance <= value) {
            revert DSC_TooPoor();
        }

        super.burn(value);
        
    }

    function mint(address account, uint256 value) external onlyOwner returns (bool) {
        if (value <= 0) {
            revert DSC_TooCheap();
        }
        if (account == address(0)) {
            revert DSC_NoZeroAddress();
        }

        _mint(account, value);
        
        return true;
        
    }


    
}