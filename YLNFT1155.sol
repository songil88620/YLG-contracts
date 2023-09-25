//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IProxy { 
    function isMintableAccount(address _address) external view returns (bool);
    function isBurnAccount(address _address) external view returns (bool);
    function isTransferAccount(address _address) external view returns (bool);
    function isPauseAccount(address _address) external view returns (bool);    
    function getCategory(uint _tokenId) external view returns(string memory);   
    function isAthleteAccount(address _address) external view returns (bool);
    function athleteMintCheck(address _address) external view returns (bool);
    function athleteMintStatus(address _address, bool _value) external returns(bool);    
    function getNFTMarket1Addr() external view returns (address);
    function getNFTMarket2Addr() external view returns (address);    
    function getYLVaultAddr() external view returns(address);
    function getAuctionAddr() external view returns(address);
    function getMarketERC1155Addr() external view returns(address);
    function getRole(address _user) external view returns(uint256);
}

contract YLNFT1155 is ERC1155URIStorage, Ownable, ReentrancyGuard {
    string public _baseURI;
    address public _ylnft1155Owner;
    IProxy public proxy;
    Counters.Counter private _newtokenId;
    bool public yltpause;

    mapping(string => mapping(string => uint256)) private categoryAmount;
    mapping(string => mapping(string => uint256)) private categoryCount;
    mapping(uint256 => uint256) private burnSignature;
    mapping(uint256 => mapping(address => bool)) private burnAddress;
    mapping(uint256 => uint256) public nftType;

    // 1:iBooster 2:pBooster 3:mBooster 4:tBooster 5:aBooster

    event minted1155( address indexed minter, uint256 tokenId, uint256 amount, string tokenUri, uint256 _type, uint256 mintedGas );
    event Burned1155( address burner, uint256 tokenId, uint256 amount, uint256 timestamp );
    event PauseContract( address admin, address minted1155contract, uint256 timestamp );
    event UnpauseContract( address admin, address minted1155contract, uint256 timestamp );
    event Transfer1155to( address indexed admin, address indexed recipient, uint256 tokenId, uint256 amount );

    constructor(string memory _yluri, IProxy _proxy) ERC1155(_yluri) {
        _baseURI = _yluri;
        _ylnft1155Owner = payable(msg.sender);
        proxy = _proxy;
    }

    function setProxyAddress(address _proxyAddress)
        public
        onlyOwner
        returns (bool)
    {
        proxy = IProxy(_proxyAddress);
        return true;
    }

    function setCategoryAmount(
        string memory _sport,
        string memory _cnft,
        uint256 _amount
    ) public onlyOwner returns (bool) {
        categoryAmount[_sport][_cnft] = _amount;
        return true;
    }

    function deleteCategory(string memory _sport, string memory _cnft)
        public
        onlyOwner
        returns (bool)
    {
        delete categoryAmount[_sport][_cnft];
        return true;
    }

    function getCategoryCount(string memory _sport, string memory _cnft)
        public
        view
        returns (uint256)
    {
        return categoryCount[_sport][_cnft];
    }

    function getCategoryAmount(string memory _sport, string memory _cnft)
        public
        view
        returns (uint256)
    {
        return categoryAmount[_sport][_cnft];
    }

    function setPauseContract(bool _yltpause) public returns (bool) {
        require(
            proxy.isPauseAccount(msg.sender),
            "you can't pause this contract, please contact the Admin"
        );
        yltpause = _yltpause;
        if (yltpause == true) {
            emit PauseContract(msg.sender, address(this), block.timestamp);
        } else {
            emit UnpauseContract(msg.sender, address(this), block.timestamp);
        }
        return true;
    }

    function getPauseContract() public view returns (bool) {
        return yltpause;
    }

    // k. Ability to Withdraw commissions to specific wallet addresses.
    function withdraw(address payable _to, uint256 _value)
        public
        nonReentrant
        onlyOwner
    {
        require(address(this).balance > _value, "Insufficient balance");
        require(getPauseContract() == true, "NFT1155 Contract was paused!");
        require(_to != address(0), "Can't transfer Coin to address(0)");

        _to.transfer(_value);
    }

    //mint
    function create1155Token(
        string memory _tokenURI,
        string memory _sport,
        string memory _cnft,  // Aditional, Coach, accesory, increase amount of games +5 more games Always.
        uint256 _amount,
        uint256 _type
    ) public returns (bool) {
        uint256 startGas = gasleft(); 
        require( proxy.getRole(msg.sender) == 8, "you don't have permission");  
        require( categoryAmount[_sport][_cnft] >= (categoryCount[_sport][_cnft]) + _amount, " Overflow! Amount of NFT category" );
        require(getPauseContract() == false, "NFT1155 Contract was paused!");

        incrementTokenId();
        uint256 newTokenId = getCurrentTokenId();
        _mint(msg.sender, newTokenId, _amount, "");
        _setURI(newTokenId, _tokenURI);

        setApprovalForAll(proxy.getMarketERC1155Addr(), true);
        setApprovalForAll(proxy.getYLVaultAddr(), true);
        setApprovalForAll(address(this), true);
        categoryCount[_sport][_cnft] += _amount;

        uint256 gasUsed = startGas - gasleft(); 
        nftType[newTokenId] = _type;
        emit minted1155(msg.sender, newTokenId, _amount, _tokenURI, _type, gasUsed);
        return true;
    }

    function lazyCreateToken(
        string memory _tokenURI,
        string memory _sport,
        string memory _cnft,
        uint256 _amount,
        uint256 _type
    ) public onlyOwner payable returns (bool) {
        require( categoryAmount[_sport][_cnft] >= (categoryCount[_sport][_cnft]) + _amount, " Overflow! Amount of NFT category" );
        require( getPauseContract() == false, "NFT721 Contract was paused!");
        // require( proxy.isMintableAccount(msg.sender), "you can't mint YL1155 NFT, please contact the Admin" );

        incrementTokenId();
        uint256 newTokenId = getCurrentTokenId();
        _mint(_ylnft1155Owner, newTokenId, _amount, "");
        _setURI(newTokenId, _tokenURI);

        setApprovalForAll(proxy.getMarketERC1155Addr(), true);
        setApprovalForAll(proxy.getYLVaultAddr(), true);
        setApprovalForAll(address(this), true);
        categoryCount[_sport][_cnft] += 1;
        nftType[newTokenId] = _type;
        emit minted1155(msg.sender, newTokenId, _amount, _tokenURI, _type, 0);        
        return true;
    }

    //transfer
    function ylnft1155Transfer(
        address _to,
        uint256 _tokenId,
        uint256 _amount
    ) public nonReentrant returns (bool) {
        require(
            proxy.isTransferAccount(msg.sender),
            "you can't transfer YL NFT, please contact the Admin"
        );
        require(getPauseContract() == false, "NFT1155 Contract was paused!");
        require(_to != address(0), "Can't transfer NFT1155 to address(0)");

        if (balanceOf(msg.sender, _tokenId) == 0) {
            return false;
        }

        safeTransferFrom(msg.sender, _to, _tokenId, _amount, "");
        emit Transfer1155to(msg.sender, _to, _tokenId, _amount);
        return true;
    }

    //transferBatch
    function ylnft1155BatchTransfer(
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) public nonReentrant returns (bool) {
        require(
            proxy.isTransferAccount(msg.sender),
            "you can't transfer YL NFT, please contact the Admin"
        );
        require(getPauseContract() == false, "NFT1155 Contract was paused!");
        require(_to != address(0), "Can't transfer NFT1155 to address(0)");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (balanceOf(msg.sender, _tokenIds[i]) < _amounts[i]) {
                return false;
            }
        }

        safeBatchTransferFrom(msg.sender, _to, _tokenIds, _amounts, "");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            emit Transfer1155to(msg.sender, _to, _tokenIds[i], _amounts[i]);
        }
        return true;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseURI = baseURI_;
    }

    function getCurrentTokenId() public view returns (uint256) {
        uint256 cId = Counters.current(_newtokenId);
        return cId;
    }

    function getNFTtype(uint256 tokenId) external view returns (uint256){
        return nftType[tokenId];
    }

    function incrementTokenId() private {
        Counters.increment(_newtokenId);
    }

    function burnNFT1155Signature(uint256 _tokenId) public returns (uint256) {
        require(proxy.isBurnAccount(msg.sender), "Only SuperAdmin or Admin");
        require(
            burnAddress[_tokenId][msg.sender] == false,
            "Already you signed"
        );
        burnAddress[_tokenId][msg.sender] = true;
        burnSignature[_tokenId] += 1;

        return burnSignature[_tokenId];
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        _burnBatch(account, ids, values);
        for(uint i = 0; i < ids.length; i++)
        {    
            emit Burned1155(msg.sender, ids[i], values[i], block.timestamp);          
        }
    }
}