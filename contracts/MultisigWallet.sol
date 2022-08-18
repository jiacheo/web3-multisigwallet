// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

/**
*  多签名钱包简单实现。
*/
contract MultisigWallet {
	
	///当前余额，单位是wei
	uint public balance;

	address owner;
    ///多签合作者，一般是平台1个，用户自己持有冷热钱包各1个。
	///协作者创建后不能更改，如果需要更改，直接新建合约，防止中间有人作弊
	address[] collaborators;
    ///最少签名人数
	uint8 at_least_sign_count;

    ///等待提款的金额
	uint waitfor_withdraw_wei;
    /// 提款的目标地址
	address payable waitfor_withdraw_address;
    ///提款发起人，发起人可以在别人未签名时取消提款
	address initiator;
    ///当前已签名的列表
	address[] current_signed;

	address[] current_cancel_counterparty_signed;

	uint public withdraw_count;

	constructor(address[] memory collaborators_, uint8 at_least_sign_count_) {
		owner = msg.sender;
		require(collaborators_.length > 0, "all collaborators count at least one");
		require(no_duplicated_collaborators(), "the collaborators must no be duplicated");
		require(at_least_sign_count_ > 0 && at_least_sign_count_ <= collaborators_.length, "at least sign count must more than 0 and less than or equals collaborators count");
		collaborators = collaborators_;
		
		at_least_sign_count = at_least_sign_count_;
	}

	function no_duplicated_collaborators() private view returns (bool) {
		bool duplicated = false;
		for(uint i=0; i<collaborators.length; i++) {
			if(i == collaborators.length - 1) {
				break;
			}
			for(uint j=i+1; j<collaborators.length; j++) {
				if(collaborators[i] == collaborators[j]) {
					duplicated = true;
					break;
				}
			}
		}
		return !duplicated;
	}

	function is_oneof_collaborators() private view returns (bool) {
		return address_array_in(collaborators, msg.sender);
	}

	/// 创建者权限, 好像没啥用
	modifier onlyOwner() {
		require(msg.sender == owner, "only owner have the permission");
		_;
	}

	/// 协作方权限
	modifier onlyCollaborators() {
		require(is_oneof_collaborators(), "only collaborators have the permission");
		_;
	}
	

	/// 充值转入，谁都可以转，用于收款
	function topin() public payable {
		require(msg.value > 0, "TOPIN must more than 0 wei, indeed the gas fee do not decrease if you topin a low value.");
		balance += msg.value;
	}

	function process_withdraw(uint weis, address payable targetAddress) public onlyCollaborators {
		require(waitfor_withdraw_wei == 0, "pre process has not been over");		
		require(weis <= balance, "withdraw balance could not more than balance");
		require(targetAddress != address(0x0), "invalid targetAddress");
		initiator = msg.sender;
		waitfor_withdraw_wei = weis;
		waitfor_withdraw_address = targetAddress;
		current_signed.push(msg.sender);
	}

	/// 增加一个另外全方，协作罢免发起方的提款请求
	/// 这是在发起方帐户丢失时才需要干的事情，防止合同废掉了，卡死在这里
	/// 发起方会先签名一次，如果金额有误且非常重大但刚好帐户丢失，直接让另外一方签署
	/// 容易导致大额损失，所以通过取消的操作来进行。
	function cancel_withdraw_by_counterparty() public onlyCollaborators {
		require(msg.sender != initiator, "only the counter party of initiator can call this function");
		require(!address_array_in(current_cancel_counterparty_signed, msg.sender), "you have signed for cancellation, don't repeat");
		require(waitfor_withdraw_wei > 0, "there isn't any withdrwals wait for cancelation");
		current_cancel_counterparty_signed.push(msg.sender);
		uint signedCount = 0;
		for(uint i=0; i<current_cancel_counterparty_signed.length; i++) {
			if(current_cancel_counterparty_signed[i] != address(0)){
				signedCount++;
			}
		}
		if(signedCount == collaborators.length - 1) {
			do_cancel_withdraw();
		}
	}

	/// 发起方才能直接取消提款
	function cancel_withdraw() public onlyCollaborators {
		require(msg.sender == initiator, "only the initiator can cancel this process");
		do_cancel_withdraw();
	}

	//取消提款，把数据都清理掉。
	function do_cancel_withdraw() private {
		delete initiator;
		delete waitfor_withdraw_address ;
		waitfor_withdraw_wei = 0;
		delete current_signed;
		delete current_cancel_counterparty_signed;
	}

	///协作方签名，只要进来这个函数，就是说明前面的以太坊认证已经通过，收集地址即可。
	///当最后一个签名方满足多签需求的时候，直接发起转账提款
	function collaboratorSign() public onlyCollaborators {
		require(waitfor_withdraw_wei > 0, "there is no withdraw action waiting for sign");
        require(!already_signed(), "you have signed this withdraw process, plz don't repeat.");
		current_signed.push(msg.sender);
		//签名已足够，可以直接转账
		if(signedCountEnough()) {
			uint weis = waitfor_withdraw_wei;
			waitfor_withdraw_wei = 0;
			waitfor_withdraw_address.transfer(weis);
			balance =  balance - weis;
			withdraw_count++;
			delete waitfor_withdraw_address ;
			delete current_signed;
			delete initiator;
			delete current_cancel_counterparty_signed;
		}
	}

	/// 判断一个地址是否是在数组里，应该利用第三方类库，而不是自己造轮子
	function address_array_in(address[] memory array, address member) private pure returns (bool) {
		bool inArray = false;
		for(uint i=0; i<array.length; i++) {
			if(array[i] == member) {
				inArray = true;
				break;
			}
		}
		return inArray;
	}

    function already_signed() private view returns (bool) {
        return address_array_in(current_signed, msg.sender);
    }

	function signedCountEnough() private view returns (bool) {
		address[] memory signed = current_signed;
		uint8 signedMatchCount = 0;
		for(uint i=0; i<signed.length; i++) {
			for(uint j=0; j<collaborators.length; j++) {
				if(collaborators[j] == signed[i]) {
					signedMatchCount++;
				}
			}
		}
		return signedMatchCount >= at_least_sign_count;
	}

}

