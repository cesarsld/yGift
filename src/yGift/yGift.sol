pragma solidity ^0.6.4;

import "../erc721/ERC721.sol";
import "../erc20/IERC20.sol";
import "./Controller.sol";
import "../utils/SafeMath.sol";

interface IERC1155 {


    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
        After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).        
        @param _from    Source address
        @param _to      Target address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;

    /**
        @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if length of `_ids` is not the same as length of `_values`.
        MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
        MUST revert on any other error.        
        MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
        Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
        After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).                      
        @param _from    Source address
        @param _to      Target address
        @param _ids     IDs of each token type (order and length must match _values array)
        @param _values  Transfer amounts per token type (order and length must match _ids array)
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;
}

library SafeERC20 {
	using SafeMath for uint256;
	using Address for address;

	function safeTransfer(IERC20 token, address to, uint256 value) internal {
		callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
	}

	function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
		callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
	}

	function safeApprove(IERC20 token, address spender, uint256 value) internal {
		require((value == 0) || (token.allowance(address(this), spender) == 0),
			"SafeERC20: approve from non-zero to non-zero allowance"
		);
		callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
	}
	function callOptionalReturn(IERC20 token, bytes memory data) private {
		require(address(token).isContract(), "SafeERC20: call to non-contract");

		// solhint-disable-next-line avoid-low-level-calls
		(bool success, bytes memory returndata) = address(token).call(data);
		require(success, "SafeERC20: low-level call failed");

		if (returndata.length > 0) { // Return data is optional
			// solhint-disable-next-line max-line-length
			require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
		}
	}
}

contract yGift is ERC721("yearn Gift NFT", "yGIFT"), Controller {
	using SafeERC20 for IERC20;
	using SafeMath for uint256;

	uint256 constant MAX_LOCK_PERIOD = 30 days;

	struct Gift {
		string	name;
		address	minter;
		address	recipient;
		address	token;
		uint256	amount;
		bool	artType;
		address	artContract;
		uint256	tokenId
		uint256	value;
		bool	redeemed;
		uint256	createdAt;
		uint256	lockedDuration;
	}

	Gift[] gifts;

	mapping(address => bool) supportedTokens;
	mapping(address => uint256) tokensHeld;

	event Tip(address indexed tipper, uint256 indexed tokenId, address token, uint256 amount, string message);
	event Collected(address indexed redeemer, uint256 indexed tokenId, address token, uint256 amount);

	/**
	 * @dev Allows controller to support a new token to be tipped
	 *
	 * _tokens: array of token addresses to whitelist
	 */
	function addTokens(address[] calldata _tokens) external onlyController {
		for (uint256 i = 0; i < _tokens.length; i++)
			supportedTokens[_tokens[i]] = true;
	}

	/**
	 * @dev Allows controller to remove the support support of a token to be tipped
	 *
	 * _tokens: array of token addresses to blacklist
	 */
	function removeTokens(address[] calldata _tokens) external onlyController {
		for (uint256 i = 0; i < _tokens.length; i++)
			supportedTokens[_tokens[i]] = false;
	}

	/**
	 * @dev Returns a gift struct
	 *
	 * _tokenId: gift in which the function caller would like to tip
	 */
	function getGift(uint256 _tokenId) public view
	returns (
		string memory,
		address,
		address,
		address,
		uint256,
		string memory,
		bool,
		uint256,
		uint256
	) {
		require(_tokenId < gifts.length, "yGift: Token ID does not exist.");
		Gift memory gift = gifts[_tokenId];
		return (
		gift.name,
		gift.minter,
		gift.recipient,
		gift.token,
		gift.amount,
		gift.artType,
		gift.artContract,
		gift.tokenId,
		goft.value,
		gift.redeemed,
		gift.createdAt,
		gift.lockedDuration
		);
	}

	/**
	 * @dev Mints a new Gift NFT and places it into the contract address for future collection
	 * _to: recipient of the gift
	 * _token: token address of the token to be gifted
	 * _amount: amount of _token to be gifted
	 * _url: URL link for the image attached to the nft
	 * _name: name of the gift
	 * _msg: Tip message given by the original minter
	 * _lockedDuration: the amount of time the gift  will be locked until the recipient can collect it 
	 *
	 * requirement: only a whitelisted minter can call this function
	 *
	 * Emits a {Tip} event.
	 */
	function mint(
		address _to,
		address _ercToken,
		uint256 _amount,
		bool	_artType;
		address	_artContract,
		uint	_tokenId
		uint	_value,
		string calldata _name,
		string calldata _msg,
		uint256 _lockedDuration)
		external onlyWhitelisted {
		require(supportedTokens[_token], "yGift: ERC20 token is not supported.");
		require(IERC20(_token).balanceOf(msg.sender) >= _amount, "yGift: Not enough token balance to mint."); 
		require(_lockedDuration <= MAX_LOCK_PERIOD, "yGift: Locked period is too large");

		uint256 _id = gifts.length;
		Gift memory gift = Gift(
			_name,
			msg.sender,
			_to,
			_token,
			_amount,
			_artType,
			_artContract,
			_tokenId,
			_value,
			false,
			block.timestamp,
			_lockedDuration);
		gifts.push(gift);
		tokensHeld[_token] = tokensHeld[_token].add(_amount);
		_safeMint(address(this), _id);
		IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
		if (_artType)
			IERC721(_artContract).safeTransferFrom(msg.sender, address(this), _tokenId);
		else
			IERC1155(_artContract).safeTransferFrom(msg.sender, address(this), _tokenId, _value, "");
		emit Tip(msg.sender, _id, _token, _amount, _msg);
	}

	/**
	 * @dev Tip some tokens to  Gift NFT 
	 * _tokenId: gift in which the function caller would like to tip
	 * _amount: amount of _token to be gifted
	 * _msg: Tip message given by the original minter
	 *
	 * Emits a {Tip} event.
	 */
	function tip(uint256 _tokenId, uint256 _amount, string memory _msg) public {
		require(_tokenId < gifts.length, "yGift: Token ID does not exist.");
		Gift storage gift = gifts[_tokenId];
		gift.amount = gift.amount.add(_amount);
		tokensHeld[gift.token] = tokensHeld[gift.token].add(_amount);
		IERC20(gift.token).safeTransferFrom(msg.sender, address(this), _amount);
		emit Tip(msg.sender, _tokenId, gift.token, _amount, _msg);
	}

	/**
	 * @dev Allows the gift recipient to redeem their gift and set
	 * the redeemed variable to true enabling token colleciton
	 *
	 * _tokenId: gift in which the function caller would like to tip
	 *
	 * requirement: caller must own the gift recipient && function must be called after the locked duration
	 */
	function redeemTokens(uint256 _tokenId) public {
		require(_tokenId < gifts.length, "yGift: Token ID does not exist.");
		Gift storage gift = gifts[_tokenId];
		require(msg.sender == gift.recipient, "yGift: You are not the recipient.");
		require(gift.createdAt.add(gift.lockedDuration) >= block.timestamp, "yGift: Gift is still locked.");
		gift.redeemed = true;
		_safeTransfer(address(this), msg.sender, _tokenId, "");
	}

	function collectArt(uint256 _tokenId) public {
		require(_tokenId < gifts.length, "yGift: Token ID does not exist.");
		require(ownerOf(_tokenId) == msg.sender, "yGift: You are not the NFT owner.");
		Gift storage gift = gifts[_tokenId];
		require(gift.redeemed, "yGift: NFT tokens cannot be collected.");
		address _artContract = gift.artContract;
		uint _tokenId = gift.tokenId;
		uint _value = gift.value;
		gift.artContract = address(0);
		gift.tokenId = 0;
		gift.valuee = 0;
		if (gift.artType) {
			IERC721(_artContract).safeTransferFrom(address(this), msg.sender, _tokenId);
		}
		else {
			IERC1155(_artContract).safeTransferFrom(address(this), msg.sender, _tokenId, _value);
		}
	}


	/**
	 * @dev Allows the gift recipient to collect their tokens
	 * _amount: amount of tokens the gift owner would like to collect
	 * _tokenId: gift in which the function caller would like to tip
	 *
	 * requirement: caller must own the gift recipient && gift must have been redeemed
	 */
	function collect(uint256 _amount, uint256 _tokenId) public {
		require(_tokenId < gifts.length, "yGift: Token ID does not exist.");
		require(ownerOf(_tokenId) == msg.sender, "yGift: You are not the NFT owner.");
		Gift storage gift = gifts[_tokenId];
		require(gift.redeemed, "yGift: NFT tokens cannot be collected.");
		gift.amount = gift.amount.sub(_amount);
		tokensHeld[gift.token] = tokensHeld[gift.token].sub(_amount);
		IERC20(gift.token).safeTransferFrom(address(this), msg.sender, _amount);
		emit Collected(msg.sender, _tokenId, gift.token, _amount);
	}

	/**
	 * @dev Allows the contract controller to remove dust tokens (air drops, accidental transfers etc)
	 * _amount: amount of tokens the gift owner would like to collect
	 * _tokenId: gift in which the function caller would like to tip
	 *
	 * requirement: caller must be controller
	 */
	function removeDust(address _token, uint256 _amount) external onlyController {
		require (IERC20(_token).balanceOf(address(this)).sub(_amount) >= tokensHeld[_token],
			"yGift: Cannot withdraw tokens.");
		IERC20(_token).safeTransferFrom(address(this), msg.sender, _amount);
	}

	function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external view returns (bytes4) {
		return yGift.onERC721Received.selector;
	}

	function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
		return yGift.onERC1155Received.selector;
	}

	function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4) {
		return yGift.onERC1155BatchReceived.selector;
	}
}