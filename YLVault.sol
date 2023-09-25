//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YLNFT.sol";
import "./Vault.sol";
import "./YLProxy.sol";

contract YLVault is Ownable{
    IERC721 public ylNFTERC721;
    IERC1155 public ylNFTERC1155;
    IERC20 public ylERC20;
    address public treasuryAddress;
    uint public revertNFTComision;
    IProxy public proxy;

    // player address => subStorageVault address
    // mapping(address => address) public vaultContract;
    mapping(address => mapping (string => address)) public vaultContract;
    // player address => SportCategory => amountNFTs Total amount of NFTs in substorage per address and Sport.  1- Footbal, 2- Basketball, 3- Rugby (Example)
    mapping(address => mapping (string => uint)) public nFTsCounter; 
    // player address => SportCategory => elegible. Gamer is elegible to play, as he added at least 5 footbal players (Example)
    mapping(address => mapping (string => bool)) public elegibleGamer; 
    // SportCategory => playersNeeded. Example: Footbal: 11;
    mapping(string => uint8) public playersNeeded;
    // Record the 721 state
    mapping(uint256 => address) public nft721owner;
    // Record the 1155 state
    mapping(address => mapping(uint256 => uint256)) public nft1155owner;


 
    event RevertNftToWalletCommissionSetted(uint256 settedFee, uint256 settedTime);
    event DepositedERC721(address from, address gamer, address vault, uint256 tokenId, uint256 depositTime);
    event DepositedERC1155(address from, address gamer, address vault, uint256 tokenId, uint256 amount, uint256 depositTime);
    event SubVaultCreated(address from, address gamer, string category, string teamname, string logo, address subaddress, uint256 createdTime );
    event RevertedERC721(address vaultAddr, address gamerAddr, uint256 nFTID, uint256 revertTime);
    event RevertedERC1155(address vaultAddr, address gamerAddr, uint256 nFTID, uint256 amount, uint256 revertTime);
    event BoostersBurned(address vaultAddr, address gamerAddr, uint256[] boosterID, uint256[] Amount, uint256 burnTime);  
    event PlayersAddedToMain(address gamerAddr, uint256 tokenId);
    event PlayersRemovedFromMain(address gamerAddr, uint256 tokenId);
    event BoosterAddedtoMain(address gamerAddr, uint256 boosterID, uint256 amount);

    constructor(IERC721 _ylNFTERC721, IERC1155 _ylNFTERC1155, IERC20 _ylERC20, IProxy _proxy) {
        ylNFTERC721 = _ylNFTERC721;
        ylNFTERC1155 = _ylNFTERC1155;
        ylERC20 = _ylERC20;
        treasuryAddress = owner();
        proxy = _proxy;
    }

    // Transfer ERC721 from Wallet to Main Vault
    function depositeERC721toMainVault(uint256[] memory _tokenIds) public {
        for(uint i = 0; i <_tokenIds.length; i++)
        {
            require(ylNFTERC721.ownerOf(_tokenIds[i]) == msg.sender, "You do not own this NFTs");
            nft721owner[_tokenIds[i]] = msg.sender;
            ylNFTERC721.transferFrom(msg.sender, address(this), _tokenIds[i]);
            emit PlayersAddedToMain(msg.sender, _tokenIds[i]);
        }
    }

    // Transfer ERC1155 from Wallet to Main Vault
    function depositeERC1155toMainVault(uint256[] memory _tokenIds, uint256[] memory _amounts) public {
        for(uint i = 0; i < _tokenIds.length; i++)
        {
            require(ylNFTERC1155.balanceOf(msg.sender, _tokenIds[i]) >= _amounts[i], "Not enough Boosters");
            ylNFTERC1155.safeTransferFrom(msg.sender, address(this), _tokenIds[i], _amounts[i], "");
            nft1155owner[msg.sender][_tokenIds[i]] += _amounts[i];
            emit BoosterAddedtoMain(msg.sender, _tokenIds[i], _amounts[i]);
        }
    }

    // Transfer ERC721 from Main Vault to Personal Vault
    function depositeERC721toSubVault(uint256[] memory _tokenIds) public {
        require(_tokenIds.length > 0, "It mustn't 0"); 
        for(uint i = 0; i < _tokenIds.length; i++)
        {
            require( nft721owner[_tokenIds[i]] == msg.sender, "You do not own this NFTs"); 
            string memory _category = YLNFT(address(ylNFTERC721)).getCategory(_tokenIds[i]);   
            // nft721owner[_tokenIds[i]] = vaultContract[msg.sender][_category];
            nFTsCounter[msg.sender][_category] += 1; //Update counter for each Sport.
            // Update elegibility
            if(nFTsCounter[msg.sender][_category] > playersNeeded[_category]) {
                elegibleGamer[msg.sender][_category] = true;
            }
            ylNFTERC721.transferFrom(address(this), vaultContract[msg.sender][_category], _tokenIds[i]);
            emit DepositedERC721(msg.sender, msg.sender, vaultContract[msg.sender][_category], _tokenIds[i], block.timestamp);
        } 
    }

    // Transfer ERC1155 from Main Vault to Personal Vault
    function depositeERC1155toSubVault(uint256 _tokenId, uint256 _amount, string memory _category) public { 
        require(_amount > 0, "It mustn't 0");
        require( nft1155owner[msg.sender][_tokenId] >= _amount, "Not enough Boosters");  
        nft1155owner[msg.sender][_tokenId] -= _amount;
       // nft1155owner[vaultContract[msg.sender][_category]][_tokenId] += _amount;        
        ylNFTERC1155.safeTransferFrom(address(this), vaultContract[msg.sender][_category], _tokenId, _amount, ""); 
        emit DepositedERC1155(msg.sender, msg.sender, vaultContract[msg.sender][_category], _tokenId, _amount, block.timestamp);
    }

    // Withdraw ERC721 from Main Vault to wallet
    function withdrawERC721toWallet(uint256 _tokenId) public {
        require(nft721owner[_tokenId] == msg.sender, "you don't have permission");
        // calculate the commission for ylg, admin, athlete
        address athlete = YLNFT(address(ylNFTERC721)).getMinter(_tokenId);
        address groupadmin = proxy.getGroupAssign(athlete);
        uint256[] memory comissions = proxy.getComissionByUser(athlete);
        uint256 price = proxy.getNftSalePrice(_tokenId);
        uint256 marketFee = price * (comissions[0]) / (10000);
        uint256 groupFee = price * (comissions[1]) / (10000);
        uint256 athleteFee = price * (comissions[2]) / (10000);
        proxy.updateEscrowAmount(athlete, athleteFee);
        proxy.updateEscrowAmount(groupadmin, groupFee);
        ylERC20.transferFrom(msg.sender, address(proxy), price); 
        ylNFTERC721.transferFrom(address(this), msg.sender, _tokenId);
        emit PlayersRemovedFromMain(msg.sender, _tokenId);
    }  
     
    
    // Create a new team with Wallet and Category
    function createAVault(address _gamer,string memory _category, string memory teamname, string memory logo) external {
        require(msg.sender == _gamer, "you don't have permission");
        if (vaultContract[_gamer][_category] == address(0x0)) {
            Vault newVault = new Vault(address(ylNFTERC721), address(ylNFTERC1155), address(ylERC20));
            vaultContract[_gamer][_category] = address(newVault);
            emit SubVaultCreated(msg.sender, _gamer, _category, teamname, logo, vaultContract[_gamer][_category], block.timestamp);
        }
    } 

    // Setter from the Vault substorage Counter when we revert NFTs to Wallet. 
    function updateCounter(address _gamer, string memory _category, uint _amount) external {
        require(vaultContract[_gamer][_category] == msg.sender, "You are not the vault owner");
        nFTsCounter[_gamer][_category] -= _amount; 
        
        if(nFTsCounter[_gamer][_category] < playersNeeded[_category]) {
            elegibleGamer[_gamer][_category] = false;
        }  
    }

    // Setter for reverting NFTs from the subvault to the owner´s wallet
    function setRevertNftToWalletCommision(uint256 _fee) external onlyOwner{
        revertNFTComision = _fee;
        emit RevertNftToWalletCommissionSetted(_fee, block.timestamp);
    }

    // Setter for the minimum number of players per category.
    function addNewSport(string memory _category, uint8 _playersNeeded) external onlyOwner{
        playersNeeded[_category] = _playersNeeded;
    }

    // Getter for the subVault of wallet address
    function getSubvault(address _gamer, string calldata _category) external view returns(address){
        return vaultContract[_gamer][_category];
    }

    // Check if the wallet is elegible to play.
    function checkElegible(address _gamer, string calldata _category) external view returns(bool){
        return elegibleGamer[_gamer][_category];
    }

    function revert721Msg(address vaultAddr, address gamerAddr, uint256 nFTID, uint256 revertTime) external{ 
       emit RevertedERC721(vaultAddr, gamerAddr, nFTID, revertTime);
    }

    function revert1155Msg(address vaultAddr, address gamerAddr, uint256 nFTID, uint256 amount, uint256 revertTime) external{  
       emit RevertedERC1155(vaultAddr, gamerAddr, nFTID, amount, revertTime);
    }

    function burnBoosterMsg(address vaultAddr, address gamerAddr, uint256[] memory boosterID, uint256[] memory Amount, uint256 burnTime) external{  
       emit BoostersBurned(vaultAddr, gamerAddr, boosterID, Amount, burnTime);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(ylNFTERC1155), "received from unauthenticated contract");
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(ylNFTERC1155), "received from unauthenticated contract");
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return true;
    }
     
}