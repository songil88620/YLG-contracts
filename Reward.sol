//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "./YLProxy.sol"; 

 
contract Reward is ReentrancyGuard, Ownable {     

    YLProxy public ylproxy;
    IERC20 public ylt20;    
  
    event DepositeToReward(address user, uint256 amount, uint256 timestamp);  
    event WithdrawFromReward(address user, uint256 amount, uint256 timestamp);
    event TransferToUser(address user, uint256 amount, uint256 timestamp);   
  

    constructor(address _ylt20, YLProxy _proxy ) { 
        ylproxy = _proxy; 
        ylt20 = IERC20(_ylt20);
    }  
   
    function depositeYLT(uint256 _amount) public onlyOwner {                
        ylt20.transferFrom(msg.sender, address(this), _amount); 
        emit DepositeToReward(msg.sender, _amount, block.timestamp); 
    }   

    function withdrawToken(uint256 _amount) public onlyOwner { 
        require(ylt20.balanceOf(address(this)) >= _amount, "insufficient fund");
        (bool sent) = ylt20.transfer(msg.sender, _amount);
        require(sent, "Failed to send token"); 
        emit WithdrawFromReward(msg.sender, _amount, block.timestamp); 
    }

    function transferToUser(address _user, uint256 _amount) public onlyOwner {
        require(ylt20.balanceOf(address(this)) >= _amount, "insufficient fund");
        (bool sent) = ylt20.transfer(_user, _amount);
        require(sent, "Failed to send token");
        emit TransferToUser(_user, _amount, block.timestamp); 
    }

}