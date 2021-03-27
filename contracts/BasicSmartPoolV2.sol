// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./other/ReentryProtection.sol";
import "./KToken.sol";
import "./storage/SmartPoolStorage.sol";
import "./libraries/ChargeModelLibrary.sol";
import "./GovIdentity.sol";
abstract contract BasicSmartPoolV2 is KToken,GovIdentity{

  event ControllerChanged(address indexed previousController, address indexed newController);
  event ChargeManagementFee(uint256 outstandingFee);
  event CapChanged(address indexed setter, uint256 oldCap, uint256 newCap);

  modifier onlyController() {
    require(msg.sender == getController(), "BasicSmartPoolV2.onlyController: not controller");
    _;
  }

  modifier withinCap() {
    _;
    require(totalSupply() <= getCap(), "BasicSmartPoolV2.withinCap: Cap limit reached");
  }

  function _init(string memory name,string memory symbol,uint8 decimals) internal override {
    super._init(name,symbol,decimals);
    _build();
  }

  function updateName(string memory name,string memory symbol)external onlyGovernance{
     super._init(name,symbol,decimals());
  }

  function getCap() public view returns (uint256){
    return SmartPoolStorage.load().cap;
  }

  function setCap(uint256 cap) external onlyGovernance {
    emit CapChanged(msg.sender, getCap(), cap);
    SmartPoolStorage.load().cap= cap;
  }

  function getController() public view returns (address){
    return SmartPoolStorage.load().controller;
  }

  function setController(address controller) public onlyGovernance {
    emit ControllerChanged(getController(), controller);
    SmartPoolStorage.load().controller= controller;
  }

  function getJoinFeeRatio() public view returns (uint256,uint256){
    return getFee(SmartPoolStorage.FeeType.JOIN_FEE);
  }

  function getExitFeeRatio() public view returns (uint256,uint256){
    return getFee(SmartPoolStorage.FeeType.EXIT_FEE);
  }

  function getFee(SmartPoolStorage.FeeType ft) public view returns (uint256,uint256){
    return ChargeModelLibrary.getFee(ft);
  }

  function setFee(SmartPoolStorage.FeeType ft,uint256 ratio,uint256 denominator) external onlyGovernance {
    if(ft==SmartPoolStorage.FeeType.MANAGEMENT_FEE){
      _chargeOutstandingManagementFee();
    }
    ChargeModelLibrary.setFee(ft,ratio,denominator);
  }

  function calcFee(SmartPoolStorage.FeeType ft,uint256 amount)public view returns(uint256){
    return ChargeModelLibrary.calcFee(ft,amount);
  }

  function chargeOutstandingManagementFee()public onlyGovernance{
     _chargeOutstandingManagementFee();
  }

  function _chargeOutstandingManagementFee()internal{
    uint256 outstandingFee = calcFee(SmartPoolStorage.FeeType.MANAGEMENT_FEE,totalSupply());
    if (outstandingFee > 0) {
      _mint(getRewards(), outstandingFee);
      ChargeModelLibrary.setFeeTime(SmartPoolStorage.FeeType.MANAGEMENT_FEE,block.timestamp);
      emit ChargeManagementFee(outstandingFee);
    }
  }
}
