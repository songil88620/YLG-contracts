//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;
// pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLNFT1155.sol";


contract YL1155Marketplace is IERC1155Receiver,ReentrancyGuard, Ownable{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    
    IERC1155 public TokenX; 
    IProxy public proxy; 
    IERC20 public ylt20;
    IERC1155 public ylNFTERC1155;

    mapping(address => conductedAuctionList)conductedAuction;
     
    mapping(address => mapping(uint256 =>uint256))participatedAuction;
     
    mapping(address => histo)history;
     
    mapping(address => uint256[])collectedArts;
    
    mapping(uint256 => bool) public pauseStatus;
     
    struct histo{
        uint256[] list;
    }
     
    struct conductedAuctionList{
        uint256[] list;
    }
     
    //mapping(uint256 => auction)auctiondetails;
    
    //mapping(address => mapping(uint256 => uint256))biddersdetails;
    
    uint256 public auctionTime = uint256(5 days);   
    
    Counters.Counter private totalAuctionId;
    Counters.Counter private totalMarketListId;
    
    enum auctionStatus { ACTIVE, OVER }
    enum State { Active, Inactive, Release}

    auction[] internal auctions;
    marketlisted[] internal marketListed;
    
    EnumerableSet.UintSet TokenIds;

    address payable market;
    
    address public vaultaddress;

    uint256 comission = 2 ;
    
    event AdminListedNFT1155(address user,uint256 tokenId, uint256 itemId, uint256 amount, uint256 price);
    event UnlistedNFT1155(address user,uint256 tokenId, uint256 itemId, uint256 price,uint256 timestamp);
    event PurchasedNFT1155(address user,uint256 tokenId, uint256 itemId, uint256 price,uint256 comission, uint256 amount);
    event UserlistedNFTtoMarket1155(address user,uint256 tokenId, uint256 itemId, uint256 price, uint256 timestamp);
    event UserNFTtoMarketSold1155(address user,uint256 tokenId, uint256 price,uint256 comission);
    event UserNFTDirectTransferto1155(address fromaddress,uint256 tokenId, address toaddress,uint256 price,uint256 comission,uint256 timestamp);
    event AdminWithdrawFromEscrow1155(address user,uint256 balance,address transferaddress,uint256 timestamp);
    event WithdrawNFTfromMarkettoWallet1155(uint256 tokenId, uint256 itemId, address withdrawaddress,uint256 comission,uint256 timestamp);
    event TransferedNFTfromMarkettoVault1155(uint256 id,address vault,uint256 timestamp);
    event AdminTransferNFT1155(address admin,uint256 tokenId, uint256 itemId, address user,uint256 timestamp);
    event MarketCommissionSet1155(address admin,uint256 comissionfee,uint256 timestamp);
    event AdminSetBid1155(address admin, uint256 tokenId, uint256 auctionId, uint256 price, uint256 time, uint256 timestamp);
    event UserSetBid1155(address admin, uint256 tokenId, uint256 auctionId, uint256 price, uint256 time, uint256 timestamp);
    event BidWinner1155(address user, uint256 auctionId, uint256 tokenId, uint256 timestamp);
    event PlaceBid(address bidder, uint256 tokenId, uint256 auctionId, uint256 price, uint256 timestamp);
    event AuctionItemEditted(address user, uint256 tokenId, uint256 period, uint256 limitPrice, uint256 timestamp);
    event MarketItemEditted(address user, uint256 tokenId, bytes data, uint256 limitPrice, uint256 timestamp);

    struct auction{
        uint256 auctionId;
        uint256 amount;
        bytes data;
        uint256 start;
        uint256 end;
        uint256 tokenId;
        address auctioner;
        address highestBidder;
        uint256 highestBid;
        address[] prevBid;
        uint256[] prevBidAmounts;
        auctionStatus status;
    }

    struct marketlisted {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 amount;
        uint256 price;
        bytes data;
        State state;
    }
 
    constructor(address _ylt20, IERC1155 _tokenx, IProxy _proxy){
        TokenX = _tokenx;
        proxy=_proxy;
        ylt20 = IERC20(_ylt20);
        ylNFTERC1155 = _tokenx;
    }
    

    function setVaultAddress(address _vaultaddress) public onlyOwner{ 
        vaultaddress=_vaultaddress;
    }

    function setComission(uint256 _comission) public onlyOwner{ 
        comission=_comission;
        emit MarketCommissionSet1155(msg.sender,_comission,block.timestamp);
    }

    function adminPauseUnpause(uint256 _auctionid) public onlyOwner{ 
        pauseStatus[_auctionid] = !pauseStatus[_auctionid];
    }

    function _ownerOf(uint256 tokenId) internal view returns (bool) {
        return TokenX.balanceOf(msg.sender, tokenId) != 0;
    }
    
    function adminAuction(uint256 _tokenId,uint256 _price,uint256 _time,uint256 amount,bytes memory data)public onlyOwner returns(uint256){
 	    require(_ownerOf(_tokenId) == true, "Auction your NFT");
	    
	    auction memory _auction = auction({
            auctionId : totalAuctionId.current(),
            amount:amount,
            data:data,
            start: block.timestamp,
            end : block.timestamp + (_time * 86400),
            tokenId: _tokenId,
            auctioner: msg.sender,
            highestBidder: msg.sender,
            highestBid: _price,
            prevBid : new address[](0),
            prevBidAmounts : new uint256[](0),
            status: auctionStatus.ACTIVE
	    });
	    
	    conductedAuctionList storage list = conductedAuction[msg.sender];
	    list.list.push(totalAuctionId.current());
	    auctions.push(_auction);
	    TokenX.safeTransferFrom(address(msg.sender), address(this), _tokenId, amount, data);
	    emit AdminSetBid1155(msg.sender, _tokenId, _auction.auctionId, _price, _time, block.timestamp);
	    totalAuctionId.increment();
	    return uint256(totalAuctionId.current());
    }

    function userAuction(uint256 _tokenId,uint256 _price,uint256 _time,uint256 amount,bytes memory data)public returns(uint256){
	    require(_ownerOf(_tokenId) == true, "Auction your NFT");
	    
	    auction memory _auction = auction({
            auctionId : totalAuctionId.current(),
            amount:amount,
            data:data,
            start: block.timestamp,
            end : block.timestamp + (_time * 86400),
            tokenId: _tokenId,
            auctioner: msg.sender,
            highestBidder: msg.sender,
            highestBid: _price,
            prevBid : new address[](0),
            prevBidAmounts : new uint256[](0),
            status: auctionStatus.ACTIVE
	    });
	    
	    conductedAuctionList storage list = conductedAuction[msg.sender];
	    list.list.push(totalAuctionId.current());
	    auctions.push(_auction);
        TokenX.safeTransferFrom(address(msg.sender), address(this), _tokenId, amount, data);
	    emit UserSetBid1155(msg.sender,  _tokenId, _auction.auctionId, _price, _time, block.timestamp);
	    totalAuctionId.increment();
	    return uint256(totalAuctionId.current());
    }

    function fetchAuctionItems() public view returns(auction[] memory) {
        uint256 total = totalAuctionId.current();

        uint256 itemCount = 0;
        for(uint i = 0; i < total; i++) {
            if(auctions[i].status == auctionStatus.ACTIVE) {
                itemCount++;
            }
        }

        auction[] memory items = new auction[](itemCount);
        uint256 index = 0;
        for(uint i = 0; i < total; i++) {
            if(auctions[i].status == auctionStatus.ACTIVE) {
                items[index] = auctions[i];
                index++;
            }
        } 
        return items;
    }

    function editAuctionItems(uint256 _auctionId, uint256 _period, uint256 price) public {
        require(auctions[_auctionId].status == auctionStatus.ACTIVE, "This auction item is not active");
        require(auctions[_auctionId].auctioner == msg.sender, "You can't edit this auction item");
        auctions[_auctionId].highestBid = price;
        auctions[_auctionId].start = block.timestamp;
        auctions[_auctionId].start = block.timestamp + (_period * 86400);
        emit AuctionItemEditted(msg.sender, auctions[_auctionId].tokenId, _period, price, block.timestamp);
    }  

    function adminListedNFT(uint256 _tokenId,uint256 _price,uint256 amount,bytes memory data) public onlyOwner returns(uint256){
        require(_ownerOf(_tokenId) == true, "you are not owner");
        marketlisted memory _marketlisted = marketlisted({
	     itemId: totalMarketListId.current(),
         tokenId: _tokenId,
         seller: msg.sender,
         owner: address(this),
         amount: amount,
         price: _price,
         data: data,
         state: State.Active         
	    });

        marketListed.push(_marketlisted);
	    TokenX.safeTransferFrom(address(msg.sender), address(this),_tokenId,amount,data);
	    
	    totalMarketListId.increment(); 
        emit AdminListedNFT1155(msg.sender, _tokenId, _marketlisted.itemId, amount, _price);
	    return uint256(totalMarketListId.current());
    }  

    function userListedNFT(uint256 _tokenId,uint256 _price,uint256 amount,bytes memory data) public returns(uint256){
        require(_ownerOf(_tokenId) == true, "you are not owner"); 

        marketlisted memory _marketlisted = marketlisted({
	     itemId: totalMarketListId.current(),
         tokenId: _tokenId,
         seller: msg.sender,
         owner: address(this),
         amount: amount,
         price: _price,
         data: data,
         state: State.Active        
	    });

        marketListed.push(_marketlisted);
	    TokenX.safeTransferFrom(address(msg.sender), address(this),_tokenId,amount,data);
	    
	    totalMarketListId.increment();
        emit UserlistedNFTtoMarket1155(msg.sender, _tokenId, _marketlisted.itemId, _price, block.timestamp);
	    return uint256(totalMarketListId.current());
    }

    function fetchListedNFTItems() public view returns(marketlisted[] memory) {
        uint256 total = totalMarketListId.current();
        
        uint256 itemCount = 0;
        for(uint i = 0; i < total; i++) {
            if(marketListed[i].state == State.Active) {
                itemCount++;
            }
        }

        marketlisted[] memory items = new marketlisted[](itemCount);
        uint256 index = 0;
        for(uint i = 0; i < total; i++) {
            if(marketListed[i].state == State.Active) {
                items[index] = marketListed[i];
                index++;
            }
        } 
        return items;
    }

    function editMarketItem(uint256 _itemId, uint256 _price, bytes memory _data) public {
        require(marketListed[_itemId].state == State.Active , "This auction item is not active");
        require(marketListed[_itemId].seller == msg.sender, "You can't edit this auction item");
        marketListed[_itemId].price = _price;
        marketListed[_itemId].data = _data; 
        emit MarketItemEditted(msg.sender, marketListed[_itemId].tokenId, _data, _price, block.timestamp);
    }

    function buyMarketListedNFT(uint256 itemId, uint256 amount) public {
        require(marketListed[itemId].seller != msg.sender,"you are seller");
        require(marketListed[itemId].state == State.Active,"already Finshed");
        
        marketlisted storage _marketlisted = marketListed[itemId];
        _marketlisted.amount = _marketlisted.amount - amount;
        require(_marketlisted.amount >= 0, "there is no to sell");
        if(_marketlisted.amount == 0){
            _marketlisted.state = State.Inactive;
        } 

        uint256 tokenType = YLNFT1155(address(ylNFTERC1155)).getNFTtype(marketListed[itemId].tokenId); 
        if(proxy.getRole(msg.sender) == 6){
            require(tokenType == 5, "you can't buy this token as your role");
        }
        
        uint256 marketFee = _marketlisted.price * (comission) / (100);
        ylt20.transferFrom(msg.sender, address(this), marketFee * amount);
        ylt20.transferFrom(msg.sender, marketListed[itemId].seller, (marketListed[itemId].price - (marketFee)) * amount); 
        TokenX.safeTransferFrom(address(this), msg.sender ,marketListed[itemId].tokenId, amount, "0x");
        emit PurchasedNFT1155(msg.sender, marketListed[itemId].tokenId, itemId, marketListed[itemId].price, marketFee, amount); 
    }   

    function unlistNFT(uint256 itemId) public{        
        require(marketListed[itemId].seller == msg.sender,"you are not seller");
        require(marketListed[itemId].state == State.Active ,"not active");
        
        marketlisted storage _marketlisted = marketListed[itemId]; 
        _marketlisted.state = State.Inactive;  
        TokenX.safeTransferFrom(address(this), marketListed[itemId].seller, marketListed[itemId].tokenId, marketListed[itemId].amount, "0x");
        emit UnlistedNFT1155(msg.sender, _marketlisted.tokenId, itemId, _marketlisted.price, block.timestamp);
    }
    
    function placeBid(uint256 _auctionId, uint256 _price)public returns(bool){
        require(pauseStatus[_auctionId] ==false,"Auction id is paused");
        require(auctions[_auctionId].highestBid < _price,"Place a higher Bid");
        require(auctions[_auctionId].auctioner != msg.sender,"Not allowed");
        require(auctions[_auctionId].end > block.timestamp,"Auction Finished");
        
        ylt20.transferFrom(msg.sender, address(this), _price);

        auction storage _auction = auctions[_auctionId];
        _auction.prevBid.push(msg.sender);
        _auction.prevBidAmounts.push(_price);
        if(participatedAuction[_auction.highestBidder][_auctionId] > 0){
            participatedAuction[_auction.highestBidder][_auctionId] = participatedAuction[_auction.highestBidder][_auctionId] + (_auction.highestBid); 
        }else{
            participatedAuction[_auction.highestBidder][_auctionId] = _auction.highestBid;
        }
        
        histo storage history = history[msg.sender];
        history.list.push(_auctionId);
        
        _auction.highestBidder = msg.sender;
        _auction.highestBid = _price;
        emit PlaceBid(msg.sender, auctions[_auctionId].tokenId, _auctionId, _price, block.timestamp);
        
        return true;
    }
    
    function finishAuction(uint256 _auctionId) public{
        require(pauseStatus[_auctionId] == false,"Auction id is paused");
        require(auctions[_auctionId].auctioner == msg.sender,"only auctioner");
        
        auction storage _auction = auctions[_auctionId];
        _auction.end = uint32(block.number);
        _auction.status = auctionStatus.OVER;
        
        uint256 marketFee = _auction.highestBid * (comission) / (100);
        
        if(_auction.prevBid.length > 0){            
            for(uint256 i = 0; i < _auction.prevBid.length-1; i++){ 
                ylt20.transfer(auctions[_auctionId].prevBid[i],  auctions[_auctionId].prevBidAmounts[i]);   
            }   
            ylt20.transfer(msg.sender, _auction.highestBid - marketFee);
            emit BidWinner1155(auctions[_auctionId].highestBidder, _auctionId, auctions[_auctionId].tokenId, block.timestamp);
            TokenX.safeTransferFrom(address(this),auctions[_auctionId].highestBidder,auctions[_auctionId].tokenId,auctions[_auctionId].amount,auctions[_auctionId].data);
        }    
    } 
    

    function adminWithdrawFromEscrow(address payable _to) public onlyOwner nonReentrant{ 
        emit AdminWithdrawFromEscrow1155(msg.sender, address(this).balance, _to, block.timestamp);
        _to.transfer(address(this).balance);
    }

    function adminWithdrawFromEscrow(uint256 amount) public onlyOwner nonReentrant{ 
        payable(msg.sender).transfer(amount);
    }

    function withdrawToken(uint256 _amount) public onlyOwner { 
        require(ylt20.balanceOf(address(this)) >= _amount, "insufficient fund");
        (bool sent) = ylt20.transfer(msg.sender, _amount);
        require(sent, "Failed to send token"); 
    }

    function withdrawNFTfromMarkettoWallet(uint256 itemId, address _to, uint256 amount, bytes memory data) public{
        require(marketListed[itemId].owner == msg.sender,"you are not owner");
        require(marketListed[itemId].state == State.Active ,"not active");
        marketlisted storage _marketlisted = marketListed[itemId]; 
        _marketlisted.state = State.Inactive;
        payable(msg.sender).transfer(comission);
        TokenX.safeTransferFrom(address(this),_to, _marketlisted.tokenId, amount, data);
        
        emit WithdrawNFTfromMarkettoWallet1155(_marketlisted.tokenId, itemId, _to, comission, block.timestamp);
    }

    function transferedNFTfromMarkettoVault(uint256 itemId, address _vaultaddress, uint256 amount, bytes memory data) public{
        require(marketListed[itemId].owner == msg.sender,"you are not owner");
        require(marketListed[itemId].state == State.Active ,"not active");
        marketlisted storage _marketlisted = marketListed[itemId];
        _marketlisted.state = State.Inactive;
        TokenX.safeTransferFrom(address(this), _vaultaddress, _marketlisted.tokenId, amount,data);
        emit TransferedNFTfromMarkettoVault1155(_marketlisted.tokenId, vaultaddress, block.timestamp);
    }

    function  adminTransferNFT(address _to, uint256 itemId, uint256 amount, bytes memory data) public onlyOwner{ 
        marketlisted storage _marketlisted = marketListed[itemId]; 
        _marketlisted.state = State.Inactive;
        emit AdminTransferNFT1155(msg.sender, _marketlisted.tokenId, itemId, _to, block.timestamp);
        TokenX.safeTransferFrom(msg.sender,_to, _marketlisted.tokenId, amount,data);
    }
    
    function auctionStatusCheck(uint256 _auctionId)public view returns(bool){
        if(auctions[_auctionId].end > block.timestamp)
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    
    function auctionInfo(uint256 _auctionId)public view returns( uint256 auctionId,
        uint256 start,
        uint256 end,
        uint256 tokenId,
        address auctioner,
        address highestBidder,
        uint256 highestBid,
        uint256 status
    ){
            
        auction storage auction = auctions[_auctionId];
        auctionId = _auctionId;
        start = auction.start;
        end =auction.end;
        tokenId = auction.tokenId;
        auctioner = auction.auctioner;
        highestBidder = auction.highestBidder;
        highestBid = auction.highestBid;
        status = uint256(auction.status);
    }
        
    function bidHistory(uint256 _auctionId) public view returns(address[]memory,uint256[]memory){
        return (auctions[_auctionId].prevBid,auctions[_auctionId].prevBidAmounts);
    }
        
    function participatedAuctions(address _user) public view returns(uint256[]memory){
        return history[_user].list;
    }
    
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(TokenX), "received from unauthenticated contract");
        TokenIds.add(id);
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(TokenX), "received from unauthenticated contract");

        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return true;
    }

    function totalAuction() public view returns(uint256){
        return auctions.length;
    }

    function conductedAuctions(address _user)public view returns(uint256[]memory){
        return conductedAuction[_user].list;
    }

    function collectedArtsList(address _user)public view returns(uint256[] memory){
        return collectedArts[_user];
    }

    
}