//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLNFTMarketplace2.sol";
import "./YLProxy.sol";
import "./YLNFT.sol"; 

interface IVault{
    function transferToMarketplace(address market, address seller, uint256 _tokenId) external;
}

contract YLNFTMarketplace1 is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;

    IProxy public proxy;
    IERC721 public ylnft; 
    IERC20 public ylt20;
    
    YLNFTMarketplace2 private nftmarket2;
    enum State { Active, Inactive, Release}

    uint256 comission = 2 ;

    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        State state;
    }

    event AdminListedNFT(address user, uint256 tokenId, uint256 itemId, uint256 price, uint256 timestamp);
    event UserlistedNFTtoMarket(address user, uint256 tokenId, uint256 itemId, uint256 price, address market, uint256 timestamp);
    event WithdrawNFTfromMarkettoWallet(uint256 tokenId, address user, uint256 commission, uint256 timestamp);
    event DepositNFTfromWallettoMarket(uint256 tokenId, address user, uint256 commission, uint256 timestamp);
    event TransferedNFTfromMarkettoVault(uint256 tokenId, address vault, address depositer, uint256 timestamp);
    event TransferedNFTfromVaulttoMarket(uint256 tokenId, address vault, uint256 timestamp);
    event AdminApprovalNFTwithdrawtoWallet(address admin, uint256 tokenId, address user, uint256 commission, uint256 timestamp);
    event DepositNFTFromWallettoMarketApproval(uint256 tokenId, address user, uint256 commission, address admin, uint256 timestamp);
    event DepositNFTFromWallettoTeamsApproval(uint256 tokenId, address user, uint256 commission, address admin, uint256 timestamp);
    event EditItem(address editor, uint256 tokenId, uint256 price, uint256 timestamp);
    event PurchasedNFT721(address buyer, uint256 tokenId, uint256 itemId, uint256 price, uint256 comission);
    event UnlistedNFT721(address user,uint256 tokenId, uint256 itemId, uint256 price,uint256 timestamp);

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(address => mapping(uint256 => bool)) depositUsers;
    mapping(address => mapping(uint256 => bool)) withdrawUsers;
    mapping(address => mapping(uint256 => bool)) depositTeamUsers;

    modifier ylOwners() {
        require(YLNFTMarketplace2(nftmarket2).getOwner(msg.sender) == true, "You aren't the owner of marketplace");
        _;
    }

    constructor(address _ylt20, IERC721 _ylnft, IProxy _proxy, YLNFTMarketplace2 _marketplace2) {
        ylnft = _ylnft;
        proxy = _proxy;
        nftmarket2 = _marketplace2; 
        ylt20 = IERC20(_ylt20);
    }

    //get itemId
    function getItemId() public view returns(uint256) {
        return _itemIds.current();
    }

    //get item data
    function getItem(uint256 _itemId) public view returns(MarketItem memory) {
        return idToMarketItem[_itemId];
    }

    function setComission(uint256 _comission) public onlyOwner{ 
        comission=_comission;
    }

    //a. Minter listed NFT to Marketplace
    function minterListedNFT(uint256 _tokenId, uint256 _price) public returns(uint256) {
        require(proxy.isMintableAccount(msg.sender), "You aren't Minter account");
        require(ylnft.ownerOf(_tokenId) == address(ylnft), "ylNFT contract haven't this token ID.");
        ylnft.transferFrom(address(ylnft), address(this), _tokenId);

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                address(ylnft),
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(ylnft);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
        }

        emit AdminListedNFT(msg.sender, _tokenId, _itemId, _price, block.timestamp);
        return _itemId;
    }

    //b. Buyer listed NFT to Marketplace
    function buyerListedNFT(uint256 _tokenId, uint256 _price) public{
        require(ylnft.ownerOf(_tokenId) == msg.sender, "User haven't this token ID.");
        require(depositUsers[msg.sender][_tokenId] == true, "This token has not been approved by administrator.");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");  
        //require(msg.value >= YLNFTMarketplace2(nftmarket2).getMarketFee(), "Insufficient Fund."); 
        // bool isTransferred = ylt20.transferFrom(msg.sender, address(this), YLNFTMarketplace2(nftmarket2).getMarketFee());
        // require(isTransferred, "Insufficient Fund.");

        ylnft.transferFrom(msg.sender, address(this), _tokenId);

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                msg.sender,
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = msg.sender;
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
        }

        emit UserlistedNFTtoMarket(msg.sender, _tokenId, _itemId, _price, address(this), block.timestamp);
    }

    function unlistNFT(uint256 itemId) public{        
        require(idToMarketItem[itemId].seller == msg.sender,"you are not seller");
        require(idToMarketItem[itemId].state == State.Active ,"not active");
        
        MarketItem storage _marketItem = idToMarketItem[itemId]; 
        _marketItem.state = State.Inactive;  
        ylnft.transferFrom(address(this), _marketItem.owner, _marketItem.tokenId);
        emit UnlistedNFT721(msg.sender, _marketItem.tokenId, itemId, _marketItem.price, block.timestamp);
    }

    function buyMarketListedNFT(uint256 itemId) public {
        require(idToMarketItem[itemId].seller != msg.sender,"you are seller");
        require(idToMarketItem[itemId].state == State.Active,"already sold");  

        MarketItem storage _marketItem = idToMarketItem[itemId];  
        _marketItem.state = State.Release;
        
        // calculate the commission for ylg, admin, athlete
        address athlete = YLNFT(address(ylnft)).getMinter(_marketItem.tokenId); 
        address groupadmin = proxy.getGroupAssign(athlete);
        uint256[] memory comissions = proxy.getComissionByUser(athlete);
        uint256 marketFee = _marketItem.price * (comissions[0]) / (10000);
        uint256 groupFee = _marketItem.price * (comissions[1]) / (10000);
        uint256 athleteFee = _marketItem.price * (comissions[2]) / (10000);
        proxy.updateEscrowAmount(athlete, athleteFee);
        proxy.updateEscrowAmount(groupadmin, groupFee);  
        proxy.updateNftSalePrice(_marketItem.tokenId, _marketItem.price);
        ylt20.transferFrom(msg.sender, address(proxy), groupFee + athleteFee);
        ylt20.transferFrom(msg.sender, address(this), marketFee);   
        ylnft.transferFrom(address(this), msg.sender, _marketItem.tokenId); 

        emit PurchasedNFT721(msg.sender, _marketItem.tokenId, itemId, _marketItem.price, marketFee); 
    }

    //i. withdraw NFT
    function withdrawNFT721(uint256 itemId) public payable nonReentrant {
        uint256 _tokenId = idToMarketItem[itemId].tokenId;
        require(idToMarketItem[itemId].seller == msg.sender, "You haven't this NFT");
        require(msg.value >= YLNFTMarketplace2(nftmarket2).getMarketFee(), "insufficient fund");
        require(withdrawUsers[msg.sender][itemId] == true, "This token has not been approved by admin"); 
       
        ylnft.transferFrom(address(this), msg.sender, _tokenId);
        idToMarketItem[itemId].state = State.Release;
        idToMarketItem[itemId].owner = msg.sender;

        emit WithdrawNFTfromMarkettoWallet(_tokenId, msg.sender, YLNFTMarketplace2(nftmarket2).getMarketFee(), block.timestamp);
    }

    //j. deposit NFT
    function depositNFT721(uint256 _tokenId, uint256 _price) public returns(uint256) {
        require(ylnft.ownerOf(_tokenId) == msg.sender, "You haven't this NFT");
        // require(msg.value >= YLNFTMarketplace2(nftmarket2).getMarketFee(), "Insufficient Fund.");
        require(depositUsers[msg.sender][_tokenId] == true, "This token has not been approved by admin.");
        require(ylnft.getApproved(_tokenId) == address(this), "NFT must be approved to market");
     
        ylnft.transferFrom(msg.sender, address(this), _tokenId);

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                address(this),
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
            idToMarketItem[_itemId].price = _price;
        }
        emit DepositNFTfromWallettoMarket(_tokenId, msg.sender, YLNFTMarketplace2(nftmarket2).getMarketFee(), block.timestamp);
        return _itemId;
    }

    // deposit approval from Admin
    function depositApproval(address _user, uint256 _tokenId, bool _flag) public ylOwners {
        require(ylnft.ownerOf(_tokenId) == _user, "The User aren't owner of this token.");
        depositUsers[_user][_tokenId] = _flag;

        emit DepositNFTFromWallettoMarketApproval(_tokenId, _user, YLNFTMarketplace2(nftmarket2).getMarketFee(), msg.sender, block.timestamp);

    }

    // withdraw approval from Admin
    function withdrawApproval(address _user, uint256 _itemId, bool _flag) public ylOwners {
        require(idToMarketItem[_itemId].seller == _user, "You don't owner of this NFT.");
        require(ylnft.ownerOf(idToMarketItem[_itemId].tokenId) == address(this), "This token don't exist in market.");
        withdrawUsers[_user][_itemId] = _flag;
        emit AdminApprovalNFTwithdrawtoWallet(msg.sender, idToMarketItem[_itemId].tokenId, _user, YLNFTMarketplace2(nftmarket2).getMarketFee(), block.timestamp);
    }

    // team approval
    function depositTeamApproval(address _user, uint256 _itemId, bool _flag) public ylOwners {
        require(ylnft.ownerOf(idToMarketItem[_itemId].tokenId) == address(this), "This token don't exist in market");
        require(idToMarketItem[_itemId].seller == _user, "The user isn't the owner of token");
        depositTeamUsers[_user][_itemId] = _flag;

        emit DepositNFTFromWallettoTeamsApproval(idToMarketItem[_itemId].tokenId, _user, YLNFTMarketplace2(nftmarket2).getMarketFee(), msg.sender, block.timestamp);

    }

    //k. To transfer the NFTs to his team(vault)
    function transferToVault(uint256 _itemId, address _vault) public nonReentrant {
        uint256 _tokenId = idToMarketItem[_itemId].tokenId;
        require(ylnft.ownerOf(_tokenId) == address(this), "This token didn't list on marketplace");
        require(idToMarketItem[_itemId].seller == msg.sender, "You don't owner of this token");
        require(depositTeamUsers[msg.sender][_itemId] == true, "This token has not been approved by admin");
        
        ylnft.transferFrom(address(this), _vault, _tokenId);
        idToMarketItem[_itemId].state = State.Release;
        idToMarketItem[_itemId].owner = _vault;

        emit TransferedNFTfromMarkettoVault(_tokenId, _vault, msg.sender, block.timestamp);
    } 

    //l. transfer from vault to marketplace
    function transferFromVaultToMarketplace(uint256 _tokenId, address _vault, uint256 _price) public {
        require(ylnft.ownerOf(_tokenId) == _vault, "The team haven't this token.");
        IVault vault = IVault(_vault);
        vault.transferToMarketplace(address(this), msg.sender, _tokenId);// Implement this function in the Vault Contract.

        uint256 _itemId = 0;
        for(uint i = 1; i <= _itemIds.current(); i++) {
            if(idToMarketItem[i].tokenId == _tokenId) {
                _itemId = idToMarketItem[i].itemId;
                break;
            }
        }

        if(_itemId == 0) {
            _itemIds.increment();
            _itemId = _itemIds.current();
            idToMarketItem[_itemId] = MarketItem(
                _itemId,
                _tokenId,
                msg.sender,
                address(this),
                _price,
                State.Active
            );
        } else {
            idToMarketItem[_itemId].state = State.Active;
            idToMarketItem[_itemId].owner = address(this);
            idToMarketItem[_itemId].seller = msg.sender;
        }

        emit TransferedNFTfromVaulttoMarket(_tokenId, _vault, block.timestamp);
    }   
   
    function editMarketItem(uint256 _itemId, uint256 _price) public {         
        require(idToMarketItem[_itemId].seller == msg.sender, "you don't have permission");
        idToMarketItem[_itemId].price = _price;
        emit EditItem(msg.sender, _itemId, _price, block.timestamp);
    }
    
    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed.");
    }

    function withdrawToken() external onlyOwner{ 
      uint256 balance = ylt20.balanceOf(address(this));
      bool success = ylt20.transfer(msg.sender, balance);
      require(success, "Withdraw failed.");
    }

    // Marketplace Listed unpaused NFTs
    function fetchMarketItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();
        
        uint256 itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Active  
                && (ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) 
                || ylnft.isApprovedForAll(address(ylnft), address(this))) {

                itemCount++;
            }
        }
        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Active  
                && (ylnft.getApproved(idToMarketItem[i].tokenId) == address(this) 
                || ylnft.isApprovedForAll(address(ylnft), address(this)))) {

                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }    
    
     // Marketplace Listed paused NFTs
    function fetchMarketPausedItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();
        
        uint256 itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToMarketItem[i].state == State.Inactive   && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                itemCount++;
            }
        }
        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToMarketItem[i].state == State.Inactive   && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }
    
    // My listed but paused NFTs
    function fetchMyPausedItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();

        uint itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Inactive 
                && idToMarketItem[i].seller == msg.sender 
                && (ylnft.getApproved(idToMarketItem[i].tokenId) == address(this))) {
                
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Inactive 
                && idToMarketItem[i].seller == msg.sender 
                && (ylnft.getApproved(idToMarketItem[i].tokenId) == address(this))) {
                
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }

    // My listed NFTs
    function fetchMyItems() public view returns(MarketItem[] memory) {
        uint256 total = _itemIds.current();

        uint itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Active 
                && idToMarketItem[i].seller == msg.sender 
                && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if( idToMarketItem[i].state == State.Active 
                && idToMarketItem[i].seller == msg.sender 
                && ylnft.getApproved(idToMarketItem[i].tokenId) == address(this)) {
                
                items[index] = idToMarketItem[i];
                index++;
            }
        }
        return items;
    }

    function withdrawToken(uint256 _amount) public onlyOwner { 
        require(ylt20.balanceOf(address(this)) >= _amount, "insufficient fund");
        (bool sent) = ylt20.transfer(msg.sender, _amount);
        require(sent, "Failed to send token"); 
    }
}