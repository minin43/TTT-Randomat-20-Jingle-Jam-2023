BettingStatus = {
    NONE = 0,
    FOLD = 1,
    CHECK = 2,
    CALL = 3,
    RAISE = 4,
    ALL_IN = 5
}

Bets = {
    NONE = 0,
    QUARTER = 1,
    HALF = 2,
    THREEQ = 3,
    ALL = 4
}

Hands = {
    NONE = 0,
    HIGH_CARD = 1,
    PAIR = 2,
    TWO_PAIR = 3,
    THREE_KIND = 4,
    STRAIGHT = 5,
    FLUSH = 6,
    FULL_HOUSE = 7,
    FOUR_KIND = 8,
    STRAIGHT_FLUSH = 9,
    ROYAL_FLUSH = 10,
    NINE_OF_DIAMONDS = 11
}

Cards = {
    NONE = 0,
    ACE = 1,
    TWO = 2,
    THREE = 3,
    FOUR = 4,
    FIVE = 5,
    SIX = 6,
    SEVEN = 7,
    EIGHT = 8,
    NINE = 9,
    TEN = 10,
    JACK = 11,
    QUEEN = 12,
    KING = 13
}

Suits = {
    NONE = 0,
    SPADES = 1,
    HEARTS = 2,
    DIAMONDS = 3,
    CLUBS = 4
}

function CardRankToName(rank)
    if rank == Cards.NONE then
        return ""
    elseif rank == Cards.ACE then
        return "ace"
    elseif rank == Cards.JACK then
        return "jack"
    elseif rank == Cards.QUEEN then
        return "queen"
    elseif rank == Cards.KING then
        return "king"
    else
        return tostring(rank)
    end
end

function BetToString(bet)
    if bet == Bets.NONE then
        return "NONE"
    elseif bet == Bets.QUARTER then
        return "QUARTER"
    elseif bet == Bets.HALF then
        return "HALF"
    elseif bet == Bets.THREEQ then
        return "THREE QUARTERS"
    elseif bet == Bets.ALL then
        return "ALL"
    else
        return ""
    end
end

function BetStatusToString(bettingStatus)
    if bettingStatus == BettingStatus.NONE then
        return "NO BET"
    elseif bettingStatus == BettingStatus.FOLD then
        return "FOLD"
    elseif bettingStatus == BettingStatus.CHECK then
        return "CHECK"
    elseif bettingStatus == BettingStatus.CALL then
        return "CALL"
    elseif bettingStatus == BettingStatus.RAISE then
        return "RAISE"
    elseif bettingStatus == BettingStatus.ALL_IN then
        return "ALL IN"
    else
        return ""
    end
end