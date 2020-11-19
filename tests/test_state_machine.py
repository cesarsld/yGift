import brownie
import pytest
from brownie import Wei
from brownie.test import strategy


def test_stateful(ygift, token, chain, giftee, receiver, state_machine):
    class StateMachine:

        address = strategy('address')
        amount = strategy("uint256", max_value="100 ether")
        start = strategy("uint256", max_value="1000000")
        duration = strategy("uint256", max_value="1500000")

        def __init__(cls, ygift, token, chain, giftee, receiver):
            cls.ygift = ygift
            cls.token = token
            cls.chain = chain
            cls.giftee = giftee
            cls.receiver = receiver

        def setup(self):
            self.token.approve(ygift, 2 ** 256 - 1)
            time = self.chain[-1].timestamp
            f_start = 500000 + time
            f_duration = 750000
            self.ygift.mint(
                self.giftee,
                self.token,
                Wei("200 ether"),
                "name",
                "msg",
                "url",
                f_start,
                f_duration,
            )


        def rule_try_redeem(self, amount, address, duration):
            self.chain.sleep(duration)
            if self.ygift.totalSupply() > 0:
                gift = self.ygift.gifts(0).dict()
                expected = self.ygift.collectible(0)
                if self.ygift.ownerOf(0) != address:
                    with brownie.reverts("yGift: You are not the NFT owner"):
                        self.ygift.collect(0, amount, {'from': address})
                else:
                    if gift["start"] <= self.chain[-1].timestamp + duration:
                        before = self.token.balanceOf(address)
                        self.ygift.collect(0, expected, {'from': address})
                        assert self.token.balanceOf(address) == expected + before
                    else:
                        with brownie.reverts("yGift: Rewards still vesting"):
                            self.ygift.collect(0, amount, {'from': address})

    state_machine(StateMachine, ygift, token, chain, giftee, receiver)
