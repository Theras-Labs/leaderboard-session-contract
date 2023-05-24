// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// TODO: //baseURI
// - subscription with active time

contract SubscriptionNFT is  ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    address public s_storeAddress;


    constructor() ERC721("Subscription Theras", "SUB-T") {
        // s_storeAddress =
    }
    // ------ MODIFIER
    modifier onlyStore() {
           require(balanceOf(msg.sender) == 0, "You already had profile token");
        _;
    }

    // ------ OWNER
   function setStore(address _storeAddress) external onlyOwner {
        s_storeAddress = _storeAddress;
    }

    // ------ PUBLIC FUNCTIONS

     function mint(address _to) external onlyStore  {
        // todo: only allowed 1 NFT too?

         uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        // _setTokenURI(tokenId, "");
        // subscribedAt[tokenCounter] = block.timestamp;

    }

 

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}

