//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLNFTMarketplace1.sol";
import "./YLNFTMarketplace2.sol";
import "./YLProxy.sol";
import "./YLNFT.sol";

contract Auction is IERC1155Receiver, ReentrancyGuard, Ownable {
    YLNFTMarketplace1 marketplaceContract1;
    YLNFTMarketplace2 marketplaceContract2;


    using Counters for Counters.Counter;
    Counters.Counter private _auctionIds;

    IERC721 public ylnft721;
    IERC1155 public ylnft1155;
    IERC20 public ylt20;
    YLProxy public ylproxy;

    enum AuctionState {Active, Release}

    struct AuctionItem {
        uint256 auctionId;
        uint256 tokenId;
        uint256 auStart;
        uint256 auEnd;
        uint256 highestBid;
        address owner;
        address highestBidder;
        address editor;
        uint256 amount;
        uint256 limitPrice;
        bool isERC721;
        AuctionState state;
    }

    event AdminSetBid(address admin, uint256 period, uint256 tokenId, uint256 auctionId, uint256 price, uint256 limitPrice, uint256 timestamp);
    event UserSetBid(address user, uint256 period, uint256 tokenId, uint256 auctionId, uint256 price, uint256 limitPrice, uint256 timestamp);
    event UserBidoffer(address user, uint256 price, uint256 tokenId, uint256 amount, uint256 bidId, uint256 timestamp);
    event BidWinner(address user, uint256 auctionId, uint256 tokenId, uint256 amount, uint256 timestamp);
    event BidNull(uint256 auctionId, uint256 tokenId, uint256 amount, address owner, uint256 timestamp);
    event AuctionItemEditted(address user, uint256 tokenId, uint256 period, uint256 limitPrice, uint256 timestamp);
    event AdminWithdrawTokens(address user, uint256 amount, uint256 timestamp);

    mapping(uint256 => AuctionItem) private idToAuctionItem;

    constructor(IERC721 _ylnft721, IERC1155 _ylnft1155, address _marketplaceContract1, address _marketplaceContract2, address _ylt20, address _ylProxy) {
        ylnft721 = _ylnft721;
        ylnft1155 = _ylnft1155;
        marketplaceContract1 = YLNFTMarketplace1(_marketplaceContract1);
        marketplaceContract2 = YLNFTMarketplace2(_marketplaceContract2);
        ylproxy = YLProxy(_ylProxy);
        ylt20 = IERC20(_ylt20);
    }

    //get auction
    function getAuctionId() public view returns(uint256) {
        return _auctionIds.current();
    }

    //get auction data
    function getAuction(uint256 _auctionId) public view returns(AuctionItem memory) {
        return idToAuctionItem[_auctionId];
    }

    function getMarketFee() public view returns (uint256) {
        return marketplaceContract2.marketfee();
    }

    //f. // Listing function by an Admin/Minter
    function MinterListNFT(uint256 _tokenId, uint256 _price, uint256 _amount, uint256 _limitPrice, uint256 _period, bool _isERC721) public returns(uint256) {
        require(ylproxy.isMintableAccount(msg.sender), "You aren't Minter account");     
        require(ylnft721.ownerOf(_tokenId) == address(ylnft721), "ylNFT contract haven't this token ID."); 
        ylnft721.transferFrom(address(ylnft721), address(this), _tokenId);  
       
        _auctionIds.increment();
        uint256 _auctionId = _auctionIds.current();
        idToAuctionItem[_auctionId] = AuctionItem (
            _auctionId,
            _tokenId,
            block.timestamp,
            block.timestamp + _period * 86400,
            _price,
            address(ylnft721),
            msg.sender,
            msg.sender,
            _amount,
            _limitPrice,
            _isERC721,
            AuctionState.Active
        ); 

        emit AdminSetBid(msg.sender, _period, _tokenId, _auctionId, _price, _limitPrice, block.timestamp);
        return _auctionId;
    }

    //g. Listing function by a buyer after the first sale
    function BuyerListNFT(uint256 _tokenId, uint256 _price, uint256 _amount, uint256 _limitPrice, uint256 _period, bool _isERC721) public returns(uint256) {
       
        require(ylnft721.ownerOf(_tokenId) == msg.sender, "You haven't this token");
        require(ylnft721.getApproved(_tokenId) == address(this), "NFT must be approved to market"); 
        ylnft721.transferFrom(msg.sender, address(this), _tokenId);    
        
        _auctionIds.increment();
        uint256 _auctionId = _auctionIds.current();
        idToAuctionItem[_auctionId] = AuctionItem (
            _auctionId,
            _tokenId,
            block.timestamp,
            block.timestamp + _period * 86400,
            _price,
            msg.sender,
            msg.sender,
            msg.sender,
            _amount,
            _limitPrice,
            _isERC721,
            AuctionState.Active
        );  

        emit UserSetBid(msg.sender, _period, _tokenId, _auctionId, _price, _limitPrice, block.timestamp);
        return _auctionId;    
    }

    function userBidOffer(uint256 _auctionId, uint256 _price, uint256 _amount, bool _isERC721) public {
        require(idToAuctionItem[_auctionId].state == AuctionState.Active, "This auction item is not active");
        require(idToAuctionItem[_auctionId].auEnd > block.timestamp, "The bidding period has already passed.");
        require(idToAuctionItem[_auctionId].highestBid < _price, "The bid price must be higher than before."); 
        require(ylnft721.ownerOf(idToAuctionItem[_auctionId].tokenId) == address(this), "This token don't exist in market."); 
        idToAuctionItem[_auctionId].highestBid = _price;
        idToAuctionItem[_auctionId].highestBidder = msg.sender;

        emit UserBidoffer(msg.sender, _price, idToAuctionItem[_auctionId].tokenId, _amount, _auctionId, block.timestamp);
    }  

    function withdrawNFTInstant(uint256 _auctionId) public nonReentrant {
        require( idToAuctionItem[_auctionId].editor != msg.sender, "You can't withdraw your NFT" );
        require( ylnft721.ownerOf(idToAuctionItem[_auctionId].tokenId) == address(this) , "This token don't exist in market." );   

        // calculate the commission for ylg, admin, athlete
        address athlete = YLNFT(address(ylnft721)).getMinter(idToAuctionItem[_auctionId].tokenId); 
        address groupadmin = ylproxy.getGroupAssign(athlete);
        uint256[] memory comissions = ylproxy.getComissionByUser(athlete);
        uint256 marketFee = idToAuctionItem[_auctionId].highestBid * (comissions[0]) / (10000);
        uint256 groupFee = idToAuctionItem[_auctionId].highestBid * (comissions[1]) / (10000);
        uint256 athleteFee = idToAuctionItem[_auctionId].highestBid * (comissions[2]) / (10000);
        ylproxy.updateEscrowAmount(athlete, athleteFee);
        ylproxy.updateEscrowAmount(groupadmin, groupFee);
        ylproxy.updateNftSalePrice(idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].highestBid);
        ylt20.transferFrom(msg.sender, address(ylproxy), groupFee + athleteFee);
        ylt20.transferFrom(msg.sender, address(this), marketFee);   
        ylnft721.transferFrom(address(this), msg.sender, idToAuctionItem[_auctionId].tokenId); 

        idToAuctionItem[_auctionId].state = AuctionState.Release;
        idToAuctionItem[_auctionId].owner = msg.sender; 
        emit BidWinner(msg.sender, _auctionId, idToAuctionItem[_auctionId].tokenId, idToAuctionItem[_auctionId].amount, block.timestamp);
    }

    function fetchAuctionItems() public view returns(AuctionItem[] memory) {
        uint256 total = _auctionIds.current();
        
        uint256 itemCount = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToAuctionItem[i].state == AuctionState.Active) {
                itemCount++;
            }
        }

        AuctionItem[] memory items = new AuctionItem[](itemCount);
        uint256 index = 0;
        for(uint i = 1; i <= total; i++) {
            if(idToAuctionItem[i].state == AuctionState.Active) {
                items[index] = idToAuctionItem[i];
                index++;
            }
        }

        return items;
    }

    function withdrawToken(uint256 _amount) public onlyOwner { 
        require(ylt20.balanceOf(address(this)) >= _amount, "insufficient fund");
        (bool sent) = ylt20.transfer(msg.sender, _amount);
        require(sent, "Failed to send token");
        emit AdminWithdrawTokens(msg.sender, _amount, block.timestamp);
    }

    function editAuctionItems(uint256 _auctionId, uint256 _period, uint256 _limitPrice) public {
        require(idToAuctionItem[_auctionId].state == AuctionState.Active, "This auction item is not active");
        require(idToAuctionItem[_auctionId].editor == msg.sender, "You can't edit this auction item");
        idToAuctionItem[_auctionId].limitPrice = _limitPrice;
        idToAuctionItem[_auctionId].auEnd = idToAuctionItem[_auctionId].auStart + _period * 86400;
        emit AuctionItemEditted(msg.sender, idToAuctionItem[_auctionId].tokenId, _period, _limitPrice, block.timestamp);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(ylnft1155), "received from unauthenticated contract");
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(ylnft1155), "received from unauthenticated contract");

        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

  function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
    return true;
  }
}