// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/kaya/IController.sol";
import "../libraries/MathExpandLibrary.sol";
import "../BasicSmartPoolV2.sol";


contract KVault is BasicSmartPoolV2{

  using SafeERC20 for IERC20;
  using MathExpandLibrary for uint256;

  address public token;

  uint256 public min_management_fee=0;

  event PoolJoined(address indexed sender,address indexed to, uint256 amount);
  event PoolExited(address indexed sender,address indexed from, uint256 amount);

  function init(string memory _name,string memory _symbol,address _token) public {
    require(token == address(0), "KVault.init: already initialised");
    require(_token != address(0), "KVault.init: _token cannot be 0x00....000");
    super._init(_name,_symbol,ERC20(_token).decimals());
    token=_token;
  }

  function setMinManagementFee(uint256 _min_management_fee)external onlyGovernance{
    min_management_fee=_min_management_fee;
  }

  function _autoChargeOutstandingManagementFee()internal{
    uint256 mfee=calcFee(SmartPoolStorage.FeeType.MANAGEMENT_FEE,totalSupply());
    if(mfee>=min_management_fee){
     _chargeOutstandingManagementFee();
    }
  }

  function joinPool(uint256 amount) public {
    IERC20 tokenContract=IERC20(token);
    require(amount<=tokenContract.balanceOf(msg.sender)&&amount>0,"KVault.joinPool: Insufficient balance");
    uint256 shares=calcTokenToKf(amount);
    uint256 fee=calcFee(SmartPoolStorage.FeeType.JOIN_FEE,shares);
    //add charge management fee
    _autoChargeOutstandingManagementFee();
    if(fee>0){
      _mint(getRewards(),fee);
    }
    _mint(msg.sender,shares.sub(fee));
    tokenContract.safeTransferFrom(msg.sender, address(this), amount);
    emit PoolJoined(msg.sender,msg.sender,shares);
  }

  function exitPool(uint256 amount) external{
    require(balanceOf(msg.sender)>=amount&&amount>0,"KVault.exitPool: Insufficient balance");
    uint256 fee=calcFee(SmartPoolStorage.FeeType.EXIT_FEE,amount);
    uint256 exitAmount=amount.sub(fee);
    uint256 tokenAmount = calcKfToToken(exitAmount);
    //add charge management fee
    _autoChargeOutstandingManagementFee();
    // Check cash balance
    IERC20 tokenContract=IERC20(token);
    uint256 cashBal = tokenContract.balanceOf(address(this));
    if (cashBal < tokenAmount) {
      uint256 diff = tokenAmount.sub(cashBal);
      IController(getController()).harvest(diff);
      tokenAmount=tokenContract.balanceOf(address(this));
    }
    tokenContract.safeTransfer(msg.sender,tokenAmount);
    if(fee>0){
      transferFrom(msg.sender,getRewards(),fee);
    }
    _burn(msg.sender,exitAmount);
    emit PoolExited(msg.sender,msg.sender,exitAmount);
  }

  function exitPoolOfUnderlying(uint256 amount)external{
    require(balanceOf(msg.sender)>=amount&&amount>0,"KVault.exitPoolOfUnderlying: Insufficient balance");
    uint256 fee=calcFee(SmartPoolStorage.FeeType.EXIT_FEE,amount);
    uint256 exitAmount=amount.sub(fee);
    uint256 tokenAmount = calcKfToToken(exitAmount);
    //add charge management fee
    _autoChargeOutstandingManagementFee();
    IController(getController()).harvestOfUnderlying(msg.sender,tokenAmount);
    if(fee>0){
      transferFrom(msg.sender,getRewards(),fee);
    }
    _burn(msg.sender,exitAmount);
    emit PoolExited(msg.sender,msg.sender,exitAmount);
  }

  function transferCash(address to,uint256 amount)external onlyController{
    require(amount>0,'KVault.transferCash: Must be greater than 0 amount');
    uint256 available = IERC20(token).balanceOf(address(this));
    require(amount<=available,'KVault.transferCash: Must be less than balance');
    IERC20(token).safeTransfer(to, amount);
  }

  function calcKfToToken(uint256 amount) public view returns(uint256){
    if(totalSupply()==0){
      return amount;
    }else{
      return (assets().mul(amount)).div(totalSupply());
    }
  }

  function calcTokenToKf(uint256 amount) public view returns(uint256){
    uint256 shares=0;
    if(totalSupply()==0){
      shares=amount;
    }else{
      shares=amount.mul(totalSupply()).div(assets());
    }
    return shares;
  }

  function assets()public view returns(uint256){
    return IERC20(token).balanceOf(address(this)).add(IController(getController()).assets());
  }

}
