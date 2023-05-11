// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "./extensions/ERC4907.sol";

contract EstateContract is
    ERC4907,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721URIStorage,
    EIP712,
    ERC2981,
    Pausable,
    Ownable
{
    using Counters for Counters.Counter;
    using SafeCast for uint256;

    event NFTSale(address lister, address buyer, uint256 price, uint256 tokenId, string uri);
    event NFTRent(address lister, address renter, uint64 expiredAt, uint256 totalPrice, uint256 tokenId, string uri);

    Counters.Counter private _tokenIdCounter;

    bytes32 private constant NFT_SALE_TYPE_HASH = keccak256("NFTForSale(address lister,uint256 price,string uri)");

    bytes32 private constant NFT_RENT_TYPE_HASH =
        keccak256(
            "NFTForRent(address lister,uint256 pricePerUnit,uint64 timeUnit,uint64 minDuration,uint64 maxDuration,string uri)"
        );

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _version,
        address _royaltyRecipient,
        uint96 _royaltyBps
    ) ERC4907(_name, _symbol) EIP712(_name, _version) {
        _setDefaultRoyalty(_royaltyRecipient, _royaltyBps);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function tokenId() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function sale(
        address to,
        address lister,
        uint256 price,
        string memory uri,
        bytes calldata signature
    ) external payable {
        require(lister != to, "Invalid address");
        require(_verify(lister, _hashNFTSale(lister, price, uri), signature), "Invalid signature");
        require(msg.value >= price, "Insufficient balance");

        uint256 _tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);

        _transferWithRefund(lister, price);

        emit NFTSale(lister, to, price, _tokenId, uri);
    }

    function rent(
        address to,
        address lister,
        uint256 pricePerUnit,
        uint64 timeUnit,
        uint64 minDuration,
        uint64 maxDuration,
        uint64 rentDuration,
        string memory uri,
        bytes calldata signature
    ) external payable {
        require(lister != to, "Invalid address");
        require(rentDuration >= minDuration && rentDuration <= maxDuration, "Invalid duration");
        require(
            _verify(lister, _hashNFTRent(lister, pricePerUnit, timeUnit, minDuration, maxDuration, uri), signature),
            "Invalid signature"
        );

        uint256 totalPrice = (pricePerUnit * rentDuration) / timeUnit;
        require(msg.value >= totalPrice, "Insufficient balance");

        uint256 _tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        // first, mint NFT to lister (owner)
        _safeMint(lister, _tokenId);
        _setTokenURI(_tokenId, uri);

        // then, set user role to renter (user)
        uint64 expiredAt = block.timestamp.toUint64() + rentDuration;
        UserInfo storage info = _users[_tokenId];
        info.user = to;
        info.expires = expiredAt;

        _transferWithRefund(lister, totalPrice);

        emit NFTRent(lister, to, expiredAt, totalPrice, _tokenId, uri);
    }

    function _hashNFTSale(address _lister, uint256 _price, string memory _uri) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(NFT_SALE_TYPE_HASH, _lister, _price, _uri)));
    }

    function _hashNFTRent(
        address _lister,
        uint256 _pricePerUnit,
        uint64 _timeUnit,
        uint64 _minDuration,
        uint64 _maxDuration,
        string memory _uri
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(NFT_RENT_TYPE_HASH, _lister, _pricePerUnit, _timeUnit, _minDuration, _maxDuration, _uri)
                )
            );
    }

    function _verify(address signer, bytes32 digest, bytes memory signature) internal view returns (bool) {
        return SignatureChecker.isValidSignatureNow(signer, digest, signature);
    }

    function _transferWithRefund(address to, uint256 amount) internal {
        uint256 refundAmount = msg.value - amount;

        (bool sent, ) = to.call{ value: amount }("");
        require(sent, "Failed to transfer");

        (bool refunded, ) = msg.sender.call{ value: refundAmount }("");
        require(refunded, "Failed to refund");
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 _tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC4907, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, _tokenId, batchSize);
    }

    function _burn(uint256 _tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(_tokenId);
        _resetTokenRoyalty(_tokenId);
    }

    function tokenURI(uint256 _tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC4907, ERC2981, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
