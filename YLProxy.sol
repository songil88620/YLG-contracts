//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract YLProxy is ReentrancyGuard, Ownable {
    address public _ylOwner;
    address public prevadmin;
    address private marketNFTAddress1;
    address private marketNFTAddress2;
    address private marketERC1155Address;
    address private ylVault;
    address private auctionAddress;
    address private nftAddress; 
    address private contestAddress;
    bool public paused;
    uint private sufficientsLength;

    IERC20 public ylt; 
    

    constructor(address _yltAddress) {
        _ylOwner = msg.sender; 
        ylt = IERC20(_yltAddress);
        mintableAccounts[msg.sender] = true;
        burnableAccounts[msg.sender] = true;
        pausableAccounts[msg.sender] = true;
        transferableAccounts[msg.sender] = true;
    }

    mapping(address => mapping(address => uint256)) public stakedAmount;
    mapping(address => bool) public mintableAccounts;
    mapping(address => bool) public burnableAccounts;
    mapping(address => bool) public pausableAccounts;
    mapping(address => bool) public transferableAccounts;
    mapping(address => bool) public athleteMinted; 
    mapping(address => uint256[]) public comissionData;
    mapping(address => address) public groupAssign;
    mapping(address => uint256) public roles;
    mapping(uint256 => uint256) public sufficientstakeamount;
    //1:HighSchool Admin 2:SportClub Admin  3:HighSchool Athlete 4:SportClub Athlete 5:Individual Athlete 6:Advertiser 7:Gamer 8: YLG Admin
    
    // keep the escrow data for every user 
    mapping(address => uint256) public escrowAmount;
    // record the nft's price for final sale
    mapping(uint256 => uint256) public nftsaleprice;

    //events
    event DepositStake(
        address indexed stakedUser,
        uint256 amount,
        address stakedContract,
        address tokenContract
    );
    event WithdrawStake(
        address indexed withdrawUser,
        uint256 amount,
        address withdrawContract,
        address tokenContract
    );
    event GrantACLto(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );
    event RemoveACLfrom(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );
    event AtheleteSet(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );
    event RemovedAthelete(
        address indexed _superadmin,
        address indexed admin,
        uint256 timestamp
    );
    event SetYLGMember(address member, bool status, uint256 timestamp);
    event ComissionSet(address admin, uint256 superadmin, uint256 teamadmin, uint256 athlete);
    event GroupAssign(address admin, address athlete);
    event SetRoles(address user, uint256 role);
    event Escrowed(address user, uint256 amount, uint256 remain);
    event UpdateNFTSalePirce(uint256 tokenId, uint256 price);

    //YLT token address
    function setYLTAddress(address _yltToken)
        external
        onlyOwner
        returns (bool)
    {
        ylt = IERC20(_yltToken);
        return true;
    }

    // ERC721 NFT address
    function setNFTAddress(address _nftAddress)
        external
        onlyOwner
        returns (bool)
    {
        nftAddress = _nftAddress;
        return true;
    }

    // NFT Market place 1
    function setMarketNFTAddress1(address _marketAddress)
        public
        onlyOwner
    {
        marketNFTAddress1 = _marketAddress;
    }

    // NFT Market place 2
    function setMarketNFTAddress2(address _marketAddress)
        public
        onlyOwner
    {
        marketNFTAddress2 = _marketAddress;
    }

    // Auction address
    function setAuctionAddress(address _auctionAddress) public onlyOwner{
        auctionAddress = _auctionAddress;
    }

    // YLVault address
    function setYLVault(address _ylVault) public onlyOwner {
        ylVault = _ylVault;
    }

    // contest address
    function setContest(address _contest) public onlyOwner {
        contestAddress = _contest;
    }

    // ERC1155 market place 
    function setERC1155Market(address _marketERC1155Address) public onlyOwner {
        marketERC1155Address  = _marketERC1155Address;  
    }

    //airdrop
    function airdrop() public {
        require(roles[msg.sender] == 8, "you don't have permission");

    }

    // record final sale price of every nft721
    function updateNftSalePrice(uint256 nftid, uint256 saleprice) public {
        require(msg.sender == auctionAddress || msg.sender == marketNFTAddress1, "you don't have permission");
        nftsaleprice[nftid] = saleprice;
        emit UpdateNFTSalePirce(nftid, saleprice);
    }

    function getNftSalePrice(uint256 nftid) public view returns(uint256 price) {
        return nftsaleprice[nftid];
    }

    function updateEscrowAmount(address _user, uint256 _amount)  public {
        require(msg.sender == auctionAddress || msg.sender == marketNFTAddress1 || msg.sender ==  ylVault || msg.sender == contestAddress , "you don't have permission");
        escrowAmount[_user] = escrowAmount[_user] + _amount;    
    }

    function escrow(uint256 _amount) public {
        require(escrowAmount[msg.sender]>=_amount, "you don't have enough amount");
        escrowAmount[msg.sender] = escrowAmount[msg.sender] - _amount;
        ylt.transfer(msg.sender, _amount);
        emit Escrowed(msg.sender, _amount, escrowAmount[msg.sender]);
    }
    
    //sufficient Amount
    function setSufficientAmount(uint256[] memory amounts)
        public
        onlyOwner
        returns (bool)
    {
        for(uint i = 0; i < amounts.length; i++){ 
            sufficientstakeamount[i] = amounts[i];
        }  
        sufficientsLength = amounts.length;
        return true;
    }

    function getSufficientAmounts() public view returns (uint256[] memory){        
        uint256[] memory suff = new uint256[](sufficientsLength);
        for(uint i = 0; i < sufficientsLength; i++){ 
            suff[i] = sufficientstakeamount[i];
        }
        return suff;
    }

    function getSufficientAmount(uint256 index) public  view  returns(uint256){
        return sufficientstakeamount[index];
    }

    //deposit
    function depositYLT(uint256 _amount) public {
        require(ylt.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(
            ylt.allowance(msg.sender, address(this)) >= _amount,
            "Insufficient allowance"
        );
        ylt.transferFrom(msg.sender, address(this), _amount);
        stakedAmount[msg.sender][address(ylt)] += _amount;
        emit DepositStake(msg.sender, _amount, address(this), address(ylt));
    }

    //withdraw
    function withdrawYLT(address _to, uint256 _amount)
        public
        onlyOwner
        nonReentrant
    {
        require(
            stakedAmount[_to][address(ylt)] >= _amount,
            "Insufficient staked amount"
        );
        stakedAmount[_to][address(ylt)] -= _amount;
        ylt.transfer(_to, _amount);
        emit WithdrawStake(_to, _amount, address(this), address(ylt));
    }

    function changeSuperAdmin(address _superadmin) external onlyOwner {
        _ylOwner = _superadmin;
    }

    //set group assign for athlete
    function setGroupAssign(address athlete) public {
        require(groupAssign[athlete] == address(0), "you don't have permission");
        require(roles[msg.sender] == 1 || roles[msg.sender] == 2 || roles[msg.sender] == 5 || roles[msg.sender] == 8, "you don't have permission");
        groupAssign[athlete] = msg.sender; 
        emit GroupAssign(msg.sender, athlete);
    }
    //get group assign for athlete
    function getGroupAssign(address athlete) public view returns(address){
        return groupAssign[athlete];
    }
    // remove group assgin
    function removeGroupAssign(address athlete) public {
        require(msg.sender == groupAssign[athlete], "you don't have permission");
        groupAssign[athlete] = address(0);
    }

    //set role for every user
    function setRoleByAdmin(address user, uint256 role) public {
        require(msg.sender == _ylOwner || roles[msg.sender] == 8, "you don't have permission");
        if(role == 8){
            require(msg.sender == _ylOwner, "you don't have permission");
        }
        roles[user] = role;
        emit SetRoles(user, role);
    }
    function setRoleByUser(address user, uint256 role) public {
        if(role == 3){
            require(roles[msg.sender] == 1, "you don't have permission");
        }
        if(role == 4){
            require(roles[msg.sender] == 2, "you don't have permission");
        }
        require(role == 3 || role == 4, "you don't have permission");         
        roles[user] = role;
        emit SetRoles(user, role);
    }
    function getRole(address user) public view returns(uint256){
        return roles[user];
    }

    //set comission data
    function setComission(address _address, uint256 _super, uint256 _admin, uint256 _athlete) public onlyOwner{         
        comissionData[_address] = new uint256[](0) ;
        comissionData[_address].push(_super);  
        comissionData[_address].push(_admin);  
        comissionData[_address].push(_athlete);     
        emit ComissionSet(_address, _super, _admin, _athlete);
    }
    //get comission data
    function getComissionByAdmin(address admin) public view returns(uint256[] memory){      
      return comissionData[admin];
    }
    function getComissionByUser(address user) public view returns(uint256[] memory){
        address admin = getGroupAssign(user);
        return comissionData[admin];
    }
    

    //mintable
    function accessMint(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            mintableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            mintableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }

    //burnable
    function accessBurn(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            burnableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            burnableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }   

    //pausable
    function accessPause(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            pausableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            pausableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }

    //transferable
    function accessTransfer(address _address, bool _value) public onlyOwner {
        if (_value == true) {
            transferableAccounts[_address] = _value;
            emit GrantACLto(msg.sender, _address, block.timestamp);
        } else {
            transferableAccounts[_address] = _value;
            emit RemoveACLfrom(msg.sender, _address, block.timestamp);
        }
    }

    function athleteMintStatus(address _address, bool _value) external returns(bool){
        require(msg.sender == _ylOwner || msg.sender == nftAddress, "Not allowed");

        athleteMinted[_address] = _value;
        return(true);        
    } 

    function isMintableAccount(address _address) external view returns (bool) {
            
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount[roles[_address]-1] &&
            mintableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isBurnAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount[roles[_address]-1] &&
            burnableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isTransferAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount[roles[_address]-1] &&
            transferableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isPauseAccount(address _address) external view returns (bool) {
        if (
            stakedAmount[_address][address(ylt)] >= sufficientstakeamount[roles[_address]-1] &&
            pausableAccounts[_address] == true
        ) {
            return true;
        } else {
            return false;
        }
    }  
    
    function athleteMintCheck(address _address) external view returns (bool) {
        return athleteMinted[_address];
    }

    function totalStakedAmount(address _user, address _contract) external view returns(uint){
        return stakedAmount[_user][_contract];
    }

    function getNFTMarket1Addr() public view returns (address){
        return marketNFTAddress1;
    }

    function getNFTMarket2Addr() public view returns (address){
        return marketNFTAddress2;
    }

    function getYLVaultAddr() public view returns(address) {
        return ylVault;
    }

    function getAuctionAddr() public view returns(address) {
        return auctionAddress;
    }

    function getMarketERC1155Addr() public view returns(address) {
        return marketERC1155Address;
    }
}